import Foundation

// Estimates the KV cache memory cost for a given context length on
// Gemma-3n-E4B-it at F16 KV precision — the single source for any UI
// that shows 'how much RAM does ctx X eat?'.
//
// Math:
//   bytes per token = 2 (K+V) × layers × kv_heads × head_dim × F16_bytes(2)
//   For Gemma-3n-E4B:  2 × 35 × 8 × 128 × 2 = 143,360 bytes ≈ 140 KB/tok
public enum KVCostEstimator {
    public static let bytesPerToken: Int = 143_360

    public static func bytes(forContext ctx: Int) -> Int {
        max(0, ctx) * bytesPerToken
    }

    public static func humanReadable(context ctx: Int) -> String {
        let b = Double(bytes(forContext: ctx))
        let gb = b / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = b / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }
}
