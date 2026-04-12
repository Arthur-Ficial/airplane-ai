import SwiftUI

// Modern Context settings: hero number + gauge, segmented size picker,
// KV cost card, hardware badges. All values read via ContextWindow +
// KVCostEstimator (SSOT).
struct ContextSettingsView: View {
    let window: ContextWindow?
    @Binding var override: Int
    @Environment(\.colorScheme) private var scheme

    private let profile = RuntimeProfileProvider().current()
    private let sizeOptions: [Int] = [0, 4096, 8192, 16384, 24576, 32768]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                sizeCard
                kvCostCard
                hardwareCard
                footer
            }
            .padding(20)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Context window").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text("model max \(format(window?.modelCapability ?? 0))")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(window?.effective ?? 0))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.accent)
                Text("tokens")
                    .font(.title3.weight(.medium)).foregroundStyle(.secondary)
            }
            gauge(effective: window?.effective ?? 0, max: window?.modelCapability ?? 32768)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Palette.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
        )
    }

    private func gauge(effective: Int, max: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: geo.size.width * fillRatio(effective, max))
            }
        }
        .frame(height: 8)
    }

    private func fillRatio(_ n: Int, _ d: Int) -> CGFloat {
        guard d > 0 else { return 0 }
        return min(1, CGFloat(n) / CGFloat(d))
    }

    // MARK: - Size picker

    private var sizeCard: some View {
        card(title: "Size", subtitle: "Changes take effect on next launch.") {
            Picker("", selection: $override) {
                ForEach(sizeOptions, id: \.self) { opt in
                    Text(label(for: opt)).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func label(for opt: Int) -> String {
        if opt == 0 { return "Auto" }
        if opt >= 1024 { return "\(opt / 1024)K" }
        return "\(opt)"
    }

    // MARK: - KV cost

    private var kvCostCard: some View {
        let effective = window?.effective ?? 0
        return card(title: "Memory cost", subtitle: "KV cache grows linearly with context length.") {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(KVCostEstimator.humanReadable(context: effective))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("KV cache").font(.caption).foregroundStyle(.secondary)
                }
                Divider().frame(height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("≈ \(KVCostEstimator.bytesPerToken / 1024) KB")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("per token at F16").font(.caption).foregroundStyle(.secondary)
                }
                Divider().frame(height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("~5 GB")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("model weights").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Hardware

    private var hardwareCard: some View {
        let memoryGB = Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0).rounded())
        return card(title: "Your Mac", subtitle: nil) {
            HStack(spacing: 10) {
                badge(icon: "memorychip", label: "\(memoryGB) GB RAM")
                badge(icon: "cpu", label: memoryClassLabel(profile.memoryClass))
                badge(icon: "bolt.fill", label: gpuLabel(profile.gpuLayerPolicy))
                Spacer()
            }
        }
    }

    private func badge(icon: String, label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private var footer: some View {
        Text("Newest user message is never silently truncated — if it doesn't fit, sending fails with a clear error.")
            .font(.caption).foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private func card<Content: View>(
        title: String, subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.tertiary) }
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func format(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    private func memoryClassLabel(_ mc: MemoryClass) -> String {
        switch mc {
        case .unsupported8to15: "8–15 GB (unsupported)"
        case .supported16to23: "16–23 GB class"
        case .supported24to31: "24–31 GB class"
        case .supported32to63: "32–63 GB class"
        case .supported64plus: "64+ GB class"
        }
    }

    private func gpuLabel(_ p: GPULayerPolicy) -> String {
        switch p {
        case .none: "CPU only"
        case .fixed(let n): "GPU × \(n) layers"
        case .all: "GPU all layers"
        }
    }
}
