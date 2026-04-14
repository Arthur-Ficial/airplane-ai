import SwiftUI

struct PrivacySettingsTab: View {
    @State private var showPrivacyPolicy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private by design").font(.title3.weight(.semibold))
                            Text("Nothing leaves your Mac. Kernel-enforced sandbox. Zero network entitlements.")
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                SettingsCard(title: "Guarantees") {
                    VStack(alignment: .leading, spacing: 10) {
                        privacyBullet("airplane", "Runs entirely on your Mac.")
                        privacyBullet("wifi.slash", "Zero network entitlements. Verified at build.")
                        privacyBullet("lock.shield", "App Sandbox enabled.")
                        privacyBullet("chart.bar.xaxis", "No telemetry. No analytics. No crash reports.")
                        privacyBullet("person.slash.fill", "No accounts. Nothing to sign up for.")
                        privacyBullet("waveform", L.privacySpeechOnDevice)
                    }
                }
                SettingsCard(title: "Legal") {
                    Button("Read Privacy Policy") { showPrivacyPolicy = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalTextView(title: "Privacy Policy", resourceName: "PrivacyPolicy")
        }
    }

    private func privacyBullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(Palette.accent)
                .frame(width: 22)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
