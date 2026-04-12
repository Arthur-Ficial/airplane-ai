import Foundation
import CLlama

public actor LlamaSwiftEngine: InferenceEngine, TokenCounter {
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var vocab: OpaquePointer?
    private var info: ModelInfo?
    private var cancellationRequested = false
    private let formatter = PromptFormatter()

    public init() {}

    public var isModelLoaded: Bool { model != nil }
    public var loadedModelInfo: ModelInfo? { info }

    public func loadModel(at path: URL, contextWindow: Int) async throws {
        LlamaSwiftEngine.ensureBackendInitialized()

        var params = llama_model_default_params()
        params.use_mmap = true
        params.use_mlock = false
        params.n_gpu_layers = Int32(Int(Int32.max)) // Metal will offload what fits

        let modelPath = path.path
        guard let m = modelPath.withCString({ llama_model_load_from_file($0, params) }) else {
            throw AppError.modelLoadFailed(summary: "llama_model_load_from_file returned nil")
        }
        self.model = m
        self.vocab = llama_model_get_vocab(m)

        var cparams = llama_context_default_params()
        cparams.n_ctx = UInt32(contextWindow)
        cparams.n_batch = 512
        cparams.n_ubatch = 512
        cparams.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        cparams.n_threads_batch = cparams.n_threads

        guard let c = llama_init_from_model(m, cparams) else {
            llama_model_free(m); self.model = nil
            throw AppError.modelLoadFailed(summary: "llama_init_from_model returned nil")
        }
        self.ctx = c

        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? NSNumber)??.int64Value ?? 0
        self.info = ModelInfo(name: path.lastPathComponent, sizeBytes: sizeBytes, sha256: "", contextWindow: contextWindow)
    }

    // Prime Metal pipelines + KV cache with a tiny decode so the first real
    // user prompt sees minimal TTFT.
    public func warmup() async {
        guard let ctx, let vocab else { return }
        let bos = llama_vocab_bos(vocab)
        var batch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(batch) }
        batch.token[0] = bos
        batch.pos[0] = 0
        batch.n_seq_id[0] = 1
        batch.seq_id[0]![0] = 0
        batch.logits[0] = 1
        batch.n_tokens = 1
        _ = llama_decode(ctx, batch)
        llama_memory_clear(llama_get_memory(ctx), true)
    }

    public func unloadModel() async {
        if let c = ctx { llama_free(c); ctx = nil }
        if let m = model { llama_model_free(m); model = nil }
        vocab = nil
        info = nil
    }

    public func cancelGeneration() async { cancellationRequested = true }

    public func countTokens(in text: String) async throws -> Int {
        guard let v = vocab else { return max(1, text.count / 4) }
        let bytes = Array(text.utf8CString)
        let n = bytes.withUnsafeBufferPointer { buf -> Int32 in
            llama_tokenize(v, buf.baseAddress, Int32(buf.count - 1), nil, 0, true, true)
        }
        return Int(-n)
    }

    public nonisolated func generate(messages: [ChatMessage], parameters: GenerationParameters) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { await self.runGeneration(messages: messages, parameters: parameters, continuation: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runGeneration(
        messages: [ChatMessage],
        parameters p: GenerationParameters,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async {
        guard let ctx, let vocab else {
            continuation.finish(throwing: AppError.modelLoadFailed(summary: "engine not loaded")); return
        }
        cancellationRequested = false
        let params = p.clamped()

        let prompt = formatter.format(systemPrompt: "", messages: messages, model: model)
        let tokenized = tokenize(prompt)
        if tokenized.isEmpty { continuation.finish(throwing: AppError.generationFailed(summary: "tokenize returned 0 tokens")); return }

        // Clear KV cache and submit prompt batch.
        llama_memory_clear(llama_get_memory(ctx), true)
        var batch = llama_batch_init(Int32(tokenized.count), 0, 1)
        defer { llama_batch_free(batch) }
        for (i, t) in tokenized.enumerated() {
            batch.token[i] = t
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i] = (i == tokenized.count - 1) ? 1 : 0
        }
        batch.n_tokens = Int32(tokenized.count)
        if llama_decode(ctx, batch) != 0 {
            continuation.finish(throwing: AppError.generationFailed(summary: "prompt decode failed")); return
        }

        // Sampler chain: top-k → top-p → temperature → dist.
        let sparams = llama_sampler_chain_default_params()
        let chain = llama_sampler_chain_init(sparams)
        defer { llama_sampler_free(chain) }
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(Int32(params.topK)))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(params.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(params.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32(bitPattern: params.seed)))

        let sanitizer = OutputSanitizer(maxOutputTokens: params.maxTokens)
        var pos = Int32(tokenized.count)
        var produced = 0
        let eos = llama_vocab_eos(vocab)
        // Rolling tail for stop-string detection.
        var tail = ""
        let maxTail = 32

        while produced < params.maxTokens {
            if cancellationRequested || Task.isCancelled {
                continuation.yield(.finished(.cancelledByUser)); continuation.finish(); return
            }
            let id = llama_sampler_sample(chain, ctx, -1)
            if id == eos {
                continuation.yield(.finished(.completed)); continuation.finish(); return
            }
            let piece = detokenize(id)

            // Detect control-token leaks (full markers + partial prefixes).
            tail += piece
            if tail.count > maxTail { tail.removeFirst(tail.count - maxTail) }
            let (_, hit) = OutputSanitizer.stripLeakingMarkers(tail)
            if hit {
                // Yield any portion of `piece` that ends before the marker begins.
                let (cleanFullTail, _) = OutputSanitizer.stripLeakingMarkers(tail)
                let kept = max(0, cleanFullTail.count - (tail.count - piece.count))
                if kept > 0 {
                    let cleanPiece = String(piece.prefix(kept))
                    if !cleanPiece.isEmpty {
                        continuation.yield(.token(TokenChunk(text: cleanPiece, tokenID: id, index: produced)))
                    }
                }
                continuation.yield(.finished(.completed)); continuation.finish(); return
            }

            let chunk = TokenChunk(text: piece, tokenID: id, index: produced)
            if let stop = sanitizer.check(chunk) {
                continuation.yield(.finished(stop)); continuation.finish(); return
            }
            continuation.yield(.token(chunk))
            produced += 1

            // Feed the sampled token back.
            batch.n_tokens = 1
            batch.token[0] = id
            batch.pos[0] = pos
            batch.n_seq_id[0] = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0] = 1
            pos += 1
            llama_sampler_accept(chain, id)
            if llama_decode(ctx, batch) != 0 {
                continuation.finish(throwing: AppError.generationFailed(summary: "decode failed mid-stream")); return
            }
        }
        continuation.yield(.finished(.outputTooLong))
        continuation.finish()
    }

    private func tokenize(_ text: String) -> [llama_token] {
        guard let vocab else { return [] }
        let utf = Array(text.utf8CString)
        let nNeg = utf.withUnsafeBufferPointer { buf -> Int32 in
            llama_tokenize(vocab, buf.baseAddress, Int32(buf.count - 1), nil, 0, true, true)
        }
        let n = Int(-nNeg)
        guard n > 0 else { return [] }
        var tokens = [llama_token](repeating: 0, count: n)
        _ = utf.withUnsafeBufferPointer { buf -> Int32 in
            tokens.withUnsafeMutableBufferPointer { tbuf -> Int32 in
                llama_tokenize(vocab, buf.baseAddress, Int32(buf.count - 1), tbuf.baseAddress, Int32(n), true, true)
            }
        }
        return tokens
    }

    private func detokenize(_ id: llama_token) -> String {
        guard let vocab else { return "" }
        var buf = [CChar](repeating: 0, count: 256)
        let n = buf.withUnsafeMutableBufferPointer { dest -> Int32 in
            llama_token_to_piece(vocab, id, dest.baseAddress, Int32(dest.count), 0, true)
        }
        if n <= 0 { return "" }
        return String(cString: Array(buf[0..<Int(n)]) + [0])
    }

    // Backend init is process-global — gate behind a lock.
    private static let backendLock = NSLock()
    nonisolated(unsafe) private static var backendInitialized = false
    nonisolated static func ensureBackendInitialized() {
        backendLock.withLock {
            if !backendInitialized { llama_backend_init(); backendInitialized = true }
        }
    }
}
