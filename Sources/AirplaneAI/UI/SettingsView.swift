import SwiftUI

// Apfel-chat inspired settings. v1 is read-mostly — no sampling sliders in
// release per spec §11.
struct SettingsView: View {
    let state: AppState?

    init(state: AppState? = nil) { self.state = state }

    var body: some View {
        TabView {
            about.tabItem { Label("About", systemImage: "info.circle") }
            privacy.tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 320)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 56, height: 56)
                    Image(systemName: "airplane")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .rotationEffect(.degrees(-20))
                }
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
        .padding(24)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet("airplane", "Runs entirely on your Mac. No cloud calls.")
            bullet("wifi.slash", "Zero network entitlements. Verified by build CI.")
            bullet("lock.shield", "App Sandbox enabled. Kernel-enforced isolation.")
            bullet("chart.bar.xaxis", "No telemetry. No analytics. No crash reports.")
            bullet("person.slash.fill", "No accounts. Nothing to sign up for.")
            Spacer()
        }
        .padding(24)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
