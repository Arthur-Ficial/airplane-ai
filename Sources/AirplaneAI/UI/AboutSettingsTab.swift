import SwiftUI

struct AboutSettingsTab: View {
    let state: AppState?
    @State private var showTermsOfUse = false
    @State private var showGemmaLicense = false
    @State private var showThirdPartyNotices = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero {
                    HStack(spacing: 14) {
                        AirplaneGlyph(size: Metrics.Size.airplaneGlyphSmall)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Airplane AI").font(.title2.weight(.semibold))
                            Text("Version \(version) (build \(build))")
                                .font(.callout).foregroundStyle(.secondary)
                            Text(L.tagline).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                SettingsCard(title: "Bundled model") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Model", value: state?.modelInfo?.name ?? "gemma-3n-E4B-it (Q4_K_M)")
                        if let info = state?.modelInfo {
                            LabeledContent("Size", value: "\(info.sizeBytes / 1_048_576) MB")
                            LabeledContent("Context window", value: "\(info.contextWindow) tok")
                        }
                        LabeledContent("Runtime", value: "llama.cpp b8763")
                    }
                }
                SettingsCard(title: "Legal") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Read Terms of Use") { showTermsOfUse = true }
                            .buttonStyle(.bordered)
                        Button("Gemma Model License") { showGemmaLicense = true }
                            .buttonStyle(.bordered)
                        Button("Third-Party Notices") { showThirdPartyNotices = true }
                            .buttonStyle(.bordered)
                    }
                }
                SettingsCard(title: "Links") {
                    VStack(alignment: .leading, spacing: 10) {
                        Link(destination: URL(string: "https://github.com/Arthur-Ficial/airplane-ai")!) {
                            Label("Source on GitHub", systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showTermsOfUse) {
            LegalTextView(title: "Terms of Use", resourceName: "TermsOfUse")
        }
        .sheet(isPresented: $showGemmaLicense) {
            LegalTextView(title: "Gemma Model License", resourceName: "Gemma-Notice")
        }
        .sheet(isPresented: $showThirdPartyNotices) {
            LegalTextView(title: "Third-Party Notices", resourceName: "ThirdPartyNotices")
        }
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
    private var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "dev"
    }
}
