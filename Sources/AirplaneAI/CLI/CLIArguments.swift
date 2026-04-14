import Foundation

public enum CLIMode: Equatable, Sendable {
    case single
    case named
    case list
    case show
    case delete
    case help
    case version
}

public enum CLIArgumentError: Error, Equatable, Sendable {
    case missingPrompt
    case missingValue(flag: String)
    case unknownFlag(String)
    case incompatibleFlags(String)
    case invalidInteger(flag: String, value: String)
}

public struct CLIArguments: Sendable, Equatable {
    public let mode: CLIMode
    public let prompt: String?
    public let name: String?
    public let continuing: Bool
    public let systemOverride: String?
    public let maxTokens: Int?
    public let seed: UInt64?
    public let quiet: Bool
    public let json: Bool

    public static func parse(_ raw: [String]) throws -> CLIArguments {
        guard !raw.isEmpty else { throw CLIArgumentError.missingPrompt }

        var prompt: String?
        var name: String?
        var continuing = false
        var systemOverride: String?
        var maxTokens: Int?
        var seed: UInt64?
        var quiet = false
        var json = false
        var explicitMode: CLIMode?
        var positional: [String] = []

        var iter = raw.makeIterator()
        func next(_ flag: String) throws -> String {
            guard let v = iter.next() else { throw CLIArgumentError.missingValue(flag: flag) }
            return v
        }

        while let arg = iter.next() {
            switch arg {
            case "-p", "--prompt":
                prompt = try next(arg)
            case "-n", "--name":
                name = try next(arg)
            case "--continue":
                continuing = true
            case "--list":
                explicitMode = .list
            case "--show":
                explicitMode = .show
            case "--delete":
                explicitMode = .delete
            case "-s", "--system":
                systemOverride = try next(arg)
            case "--max-tokens":
                let raw = try next(arg)
                guard let v = Int(raw) else {
                    throw CLIArgumentError.invalidInteger(flag: arg, value: raw)
                }
                maxTokens = v
            case "--seed":
                let raw = try next(arg)
                guard let v = UInt64(raw) else {
                    throw CLIArgumentError.invalidInteger(flag: arg, value: raw)
                }
                seed = v
            case "-q", "--quiet":
                quiet = true
            case "--json":
                json = true
            case "-h", "--help":
                explicitMode = .help
            case "-v", "--version":
                explicitMode = .version
            default:
                if arg.hasPrefix("-") {
                    throw CLIArgumentError.unknownFlag(arg)
                }
                positional.append(arg)
            }
        }

        if prompt == nil, let first = positional.first {
            prompt = positional.count == 1 ? first : positional.joined(separator: " ")
        }

        if let mode = explicitMode {
            switch mode {
            case .show, .delete:
                guard name != nil else {
                    throw CLIArgumentError.incompatibleFlags("\(mode) requires --name")
                }
            case .list, .help, .version:
                break
            case .single, .named:
                break
            }
            return CLIArguments(
                mode: mode, prompt: prompt, name: name, continuing: continuing,
                systemOverride: systemOverride, maxTokens: maxTokens, seed: seed,
                quiet: quiet, json: json
            )
        }

        guard let finalPrompt = prompt, !finalPrompt.isEmpty else {
            throw CLIArgumentError.missingPrompt
        }

        if continuing, name == nil {
            throw CLIArgumentError.incompatibleFlags("--continue requires --name")
        }

        let mode: CLIMode = name == nil ? .single : .named
        return CLIArguments(
            mode: mode, prompt: finalPrompt, name: name, continuing: continuing,
            systemOverride: systemOverride, maxTokens: maxTokens, seed: seed,
            quiet: quiet, json: json
        )
    }

    /// True when the process arguments contain any CLI-mode flag.
    /// GUI launch (plain `AirplaneAI`) and `--seed-sample-conversations` stay GUI/headless-seed.
    public static func isCLIInvocation(arguments: [String]) -> Bool {
        let cliTriggers: Set<String> = [
            "-p", "--prompt",
            "-n", "--name",
            "--list", "--show", "--delete",
            "-h", "--help",
            "-v", "--version",
        ]
        for arg in arguments.dropFirst() {
            if cliTriggers.contains(arg) { return true }
        }
        return false
    }
}
