import SwiftUI

struct SettingsView: View {
    let state: AppState?
    let store: (any ConversationStore)?
    @AppStorage("airplane.appearance") private var appearance: String = "system"
    @AppStorage("airplane.timeFormat") private var timeFormat: String = "relative"
    @AppStorage("airplane.sendWith") private var sendWith: String = "enter"
    @AppStorage("airplane.contextOverride") private var contextOverride: Int = 0
    @AppStorage("airplane.showTokenCounts") private var showTokenCounts: Bool = true

    init(state: AppState? = nil, store: (any ConversationStore)? = nil) {
        self.state = state
        self.store = store
    }

    var body: some View {
        TabView {
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            keyboardTab.tabItem { Label("Keyboard", systemImage: "keyboard") }
            contextTab.tabItem { Label("Context", systemImage: "text.alignleft") }
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }
            privacyTab.tabItem { Label("Privacy", systemImage: "lock.shield") }
            dangerTab.tabItem { Label("Danger Zone", systemImage: "exclamationmark.triangle") }
            #if AIRPLANE_DEBUG
            debugTab.tabItem { Label("Debug", systemImage: "ant") }
            #endif
        }
        .frame(width: 680, height: 580)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "Theme") {
                    Picker("", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                SettingsCard(title: "Sidebar timestamps") {
                    Picker("", selection: $timeFormat) {
                        Text("Relative").tag("relative")
                        Text("Absolute").tag("absolute")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    Text(timeFormat == "relative"
                         ? "e.g. \"2 hours ago\""
                         : "e.g. \"Apr 12 15:04\"")
                        .font(.caption).foregroundStyle(.secondary)
                }
                SettingsCard(title: "Token counts") {
                    Toggle(L.showTokenCounts, isOn: $showTokenCounts)
                        .toggleStyle(.switch)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Keyboard

    private var keyboardTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "Composer", subtitle: "How Enter behaves in the message box.") {
                    Picker("", selection: $sendWith) {
                        Text("Enter = send").tag("enter")
                        Text("⌘+Enter = send").tag("cmd-enter")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    Text(sendWith == "cmd-enter"
                         ? "Plain Enter inserts a newline."
                         : "Shift+Enter inserts a newline.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                SettingsCard(title: "Shortcuts") {
                    VStack(alignment: .leading, spacing: 10) {
                        shortcutRow("New chat", "⌘N")
                        shortcutRow("Focus search", "⌘K")
                        shortcutRow("Open Settings", "⌘,")
                        shortcutRow("Cancel / clear draft", "⎋")
                        shortcutRow("Send (always works)", "⌘↩")
                    }
                }
            }
            .padding(20)
        }
    }

    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            Text(shortcut)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
    }

    // MARK: - Context

    private var contextTab: some View {
        ContextSettingsView(window: state?.contextWindow, override: $contextOverride)
    }

    // MARK: - About

    private var aboutTab: some View {
        AboutSettingsTab(state: state)
    }

    // MARK: - Privacy

    private var privacyTab: some View {
        PrivacySettingsTab()
    }

    // MARK: - Danger Zone

    private var dangerTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Danger Zone").font(.title3.weight(.semibold)).foregroundStyle(.red)
                            Text("These actions cannot be undone.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                SettingsCard(title: "Delete all conversations",
                             subtitle: "Wipes every chat plus rolling backup snapshots.") {
                    Button(role: .destructive) {
                        Task { await deleteAllConversations() }
                    } label: {
                        Label("Delete everything", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)
                }
            }
            .padding(20)
        }
    }

    private func deleteAllConversations() async {
        guard let store else { return }
        do {
            let all = try await store.allConversations()
            for c in all { try? await store.delete(id: c.id) }
            await MainActor.run { state?.conversations.removeAll() }
        } catch {}
    }

    // MARK: - Debug

    #if AIRPLANE_DEBUG
    @AppStorage("airplane.debug.temperature") private var debugTemperature: Double = 0.6
    @AppStorage("airplane.debug.topP") private var debugTopP: Double = 0.95
    @AppStorage("airplane.debug.topK") private var debugTopK: Int = 40
    @AppStorage("airplane.debug.maxTokens") private var debugMaxTokens: Int = 1024

    private var debugTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero {
                    HStack(spacing: 14) {
                        Image(systemName: "ant.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug sampling").font(.title3.weight(.semibold))
                            Text("Stripped from release builds per spec §11.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                SettingsCard(title: "Sampling parameters") {
                    VStack(alignment: .leading, spacing: 12) {
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
                }
                SettingsCard(title: "Reset") {
                    Button("Reset to defaults") {
                        debugTemperature = 0.6; debugTopP = 0.95
                        debugTopK = 40; debugMaxTokens = 1024
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
    }
    #endif

}
