import SwiftUI

struct SettingsView: View {
    let state: AppState?
    let store: (any ConversationStore)?
    @AppStorage("airplane.appearance") private var appearance: String = "system"
    @AppStorage("airplane.timeFormat") private var timeFormat: String = "relative"
    @AppStorage("airplane.sendWith") private var sendWith: String = "enter"

    init(state: AppState? = nil, store: (any ConversationStore)? = nil) {
        self.state = state
        self.store = store
    }

    var body: some View {
        TabView {
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            keyboardTab.tabItem { Label("Keyboard", systemImage: "keyboard") }
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }
            privacyTab.tabItem { Label("Privacy", systemImage: "lock.shield") }
            dangerTab.tabItem { Label("Danger Zone", systemImage: "exclamationmark.triangle") }
            #if AIRPLANE_DEBUG
            debugTab.tabItem { Label("Debug", systemImage: "ant") }
            #endif
        }
        .frame(width: 560, height: 400)
    }

    #if AIRPLANE_DEBUG
    @AppStorage("airplane.debug.temperature") private var debugTemperature: Double = 0.6
    @AppStorage("airplane.debug.topP") private var debugTopP: Double = 0.95
    @AppStorage("airplane.debug.topK") private var debugTopK: Int = 40
    @AppStorage("airplane.debug.maxTokens") private var debugMaxTokens: Int = 1024

    private var debugTab: some View {
        Form {
            Section("Sampling (DEBUG only — never in release builds)") {
                VStack(alignment: .leading) {
                    Text("Temperature: \(debugTemperature, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $debugTemperature, in: 0...1.5)
                }
                VStack(alignment: .leading) {
                    Text("top-p: \(debugTopP, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $debugTopP, in: 0.01...1.0)
                }
                Stepper("top-k: \(debugTopK)", value: $debugTopK, in: 1...200)
                Stepper("max tokens: \(debugMaxTokens)", value: $debugMaxTokens, in: 1...4096, step: 64)
            }
            Section {
                Button("Reset to defaults") {
                    debugTemperature = 0.6; debugTopP = 0.95
                    debugTopK = 40; debugMaxTokens = 1024
                }
            }
        }
        .formStyle(.grouped)
        .padding(Metrics.Padding.large)
    }
    #endif

    private var appearanceTab: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("Follow System").tag("system")
                Text("Always Light").tag("light")
                Text("Always Dark").tag("dark")
            }
            .pickerStyle(.inline)
            Picker("Sidebar timestamps", selection: $timeFormat) {
                Text("Relative (2h ago)").tag("relative")
                Text("Absolute (Apr 12 15:04)").tag("absolute")
            }
            .pickerStyle(.inline)
        }
        .formStyle(.grouped)
        .padding(Metrics.Padding.large)
    }

    private var keyboardTab: some View {
        Form {
            Section("Composer") {
                Picker("Send with", selection: $sendWith) {
                    Text("Enter (Shift+Enter = newline)").tag("enter")
                    Text("Cmd+Enter (Enter = newline)").tag("cmd-enter")
                }
                .pickerStyle(.inline)
            }
            Section("Shortcuts") {
                shortcutRow("New chat", "⌘N")
                shortcutRow("Focus search", "⌘K")
                shortcutRow("Open Settings", "⌘,")
                shortcutRow("Cancel / clear draft", "⎋")
                shortcutRow("Send", "⌘↩")
            }
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
                    Text("Version \(version) (build \(build))").font(.caption).foregroundStyle(.secondary)
                    Text(L.tagline).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            if let info = state?.modelInfo {
                LabeledContent("Model", value: info.name)
                LabeledContent("Context window", value: "\(info.contextWindow)")
                LabeledContent("Size", value: "\(info.sizeBytes / 1_048_576) MB")
            } else {
                LabeledContent("Model", value: "Gemma-3n-E4B-it (Q4_K_M)")
            }
            LabeledContent("Runtime", value: "llama.cpp b8763")
            Link("Source on GitHub", destination: URL(string: "https://github.com/franzenzenhofer/airplane-ai")!)
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

    private var dangerTab: some View {
        VStack(alignment: .leading, spacing: Metrics.Padding.regular) {
            Text("Danger Zone").font(.headline).foregroundStyle(.red)
            Text("These actions cannot be undone.").foregroundStyle(.secondary).font(.callout)
            Divider()
            Button(role: .destructive) {
                Task { await deleteAllConversations() }
            } label: {
                Label("Delete all conversations", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            Spacer()
        }
        .padding(Metrics.Padding.large * 1.5)
    }

    private func deleteAllConversations() async {
        guard let store else { return }
        do {
            let all = try await store.allConversations()
            for c in all { try? await store.delete(id: c.id) }
            await MainActor.run { state?.conversations.removeAll() }
        } catch {}
    }

    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        LabeledContent(label) {
            Text(shortcut).font(.system(.callout, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
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
    private var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "dev"
    }
}
