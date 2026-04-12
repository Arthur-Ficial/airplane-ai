import SwiftUI

struct SettingsView: View {
    let state: AppState?
    @AppStorage("airplane.appearance") private var appearance: String = "system"

    init(state: AppState? = nil) { self.state = state }

    var body: some View {
        TabView {
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }
            privacyTab.tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 360)
    }

    private var appearanceTab: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("Follow System").tag("system")
                Text("Always Light").tag("light")
                Text("Always Dark").tag("dark")
            }
            .pickerStyle(.inline)
        }
        .formStyle(.grouped)
        .padding(Metrics.Padding.large)
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: Metrics.Padding.regular) {
            HStack(spacing: Metrics.Padding.regular) {
                AirplaneGlyph(size: Metrics.Size.airplaneGlyphSmall)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Airplane AI").font(.title2.weight(.semibold))
                    Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                    Text(L.tagline).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            if let info = state?.modelInfo {
                LabeledContent("Model", value: info.name)
                LabeledContent("Context window", value: "\(info.contextWindow)")
            } else {
                LabeledContent("Model", value: "Gemma E4B (Q4_K_M)")
            }
            LabeledContent("Runtime", value: "llama.cpp b8763")
            Spacer()
        }
        .padding(Metrics.Padding.large * 1.5)
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: Metrics.Padding.regular) {
            bullet("airplane", "Runs entirely on your Mac. No cloud calls.")
            bullet("wifi.slash", "Zero network entitlements. Verified by build CI.")
            bullet("lock.shield", "App Sandbox enabled. Kernel-enforced isolation.")
            bullet("chart.bar.xaxis", "No telemetry. No analytics. No crash reports.")
            bullet("person.slash.fill", "No accounts. Nothing to sign up for.")
            Spacer()
        }
        .padding(Metrics.Padding.large * 1.5)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.Padding.small) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
