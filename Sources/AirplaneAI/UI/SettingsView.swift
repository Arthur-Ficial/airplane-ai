import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Airplane AI", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                Text(L.tagline).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Text("This app runs entirely on your Mac. It has no network access, no telemetry, and no accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 280)
    }
}
