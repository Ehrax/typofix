import SwiftUI

struct SettingsSceneView: View {
    @State private var viewModel: SettingsViewModel

    private let onLaunchAtLoginDidChange: () -> Void
    private let onShortcutsDidChange: () -> Void

    init(
        configStore: ConfigStore,
        onLaunchAtLoginDidChange: @escaping () -> Void,
        onShortcutsDidChange: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: SettingsViewModel(configStore: configStore))
        self.onLaunchAtLoginDidChange = onLaunchAtLoginDidChange
        self.onShortcutsDidChange = onShortcutsDidChange
    }

    var body: some View {
        SettingsRootView(viewModel: viewModel)
            .frame(minWidth: 620, idealWidth: 680, minHeight: 420, idealHeight: 480)
            .windowResizeAnchor(.top)
            .onAppear {
                viewModel.launchAtLoginDidChange = onLaunchAtLoginDidChange
                viewModel.shortcutsDidChange = onShortcutsDidChange
                viewModel.load()
            }
    }
}

struct SettingsRootView: View {
    @Bindable var viewModel: SettingsViewModel
    @SceneStorage("typofix.settings.selection") private var selectionID = SettingsSection.general.rawValue

    private var selection: Binding<SettingsSection?> {
        Binding {
            SettingsSection(rawValue: selectionID) ?? .general
        } set: { newValue in
            selectionID = (newValue ?? .general).rawValue
        }
    }

    private var selectedSection: SettingsSection {
        SettingsSection(rawValue: selectionID) ?? .general
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            selectedDetail
                .navigationTitle(selectedSection.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var selectedDetail: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        case .shortcuts:
            ShortcutsSettingsView(viewModel: viewModel)
        case .providers:
            ProvidersSettingsView(viewModel: viewModel)
        }
    }
}

private struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Fast model", selection: $viewModel.fastModelSelectionKey) {
                    ForEach(viewModel.modelOptions(for: .fast), id: \.selectionKey) { option in
                        Text(option.menuTitle).tag(option.selectionKey)
                    }
                }

                Picker("Smart model", selection: $viewModel.smartModelSelectionKey) {
                    ForEach(viewModel.modelOptions(for: .smart), id: \.selectionKey) { option in
                        Text(option.menuTitle).tag(option.selectionKey)
                    }
                }
            } header: {
                Text("Models")
            } footer: {
                Text("Fast model runs the double-tap typo fix. Smart model powers rewrite variants and custom instructions.")
            }

            Section {
                Toggle("Start at Login", isOn: Binding(
                    get: { viewModel.isLaunchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLoginEnabled($0) }
                ))
                .disabled(!viewModel.launchAtLoginAvailable)
            } header: {
                Text("System")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.launchAtLoginAvailable
                        ? "Open Typofix automatically when you sign in."
                        : LaunchAtLogin.unavailableTooltip)

                    if let errorMessage = viewModel.launchAtLoginErrorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scenePadding()
    }
}

private struct ShortcutsSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Fast fix", selection: Binding(
                    get: { viewModel.fastShortcut },
                    set: { viewModel.updateFastShortcut($0) }
                )) {
                    ForEach(HotkeyShortcut.allCases, id: \.self) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }

                Picker("Rewrite bar", selection: Binding(
                    get: { viewModel.rewriteShortcut },
                    set: { viewModel.updateRewriteShortcut($0) }
                )) {
                    ForEach(HotkeyShortcut.allCases, id: \.self) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
            } header: {
                Text("Keyboard")
            } footer: {
                Text("Fast fix runs the selected fast model on the current text field. Rewrite bar opens the rewrite picker. Each active shortcut must be unique.")
            }
        }
        .formStyle(.grouped)
        .scenePadding()
    }
}

private struct ProvidersSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isGroqKeyVisible = false
    @State private var isAnthropicKeyVisible = false

    var body: some View {
        Form {
            Section {
                APIKeyField(
                    "Groq",
                    text: $viewModel.groqAPIKey,
                    isVisible: $isGroqKeyVisible,
                    prompt: "GROQ_API_KEY or config.json"
                )

                APIKeyField(
                    "Anthropic",
                    text: $viewModel.anthropicAPIKey,
                    isVisible: $isAnthropicKeyVisible,
                    prompt: "ANTHROPIC_API_KEY or config.json"
                )
            } header: {
                Text("Cloud Providers")
            } footer: {
                Text("Keys are stored in ~/.config/typofix/config.json and used by the matching models above.")
            }

            Section {
                LabeledContent("Apple Foundation") {
                    Text(viewModel.appleFoundationStatus)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Local Providers")
            } footer: {
                Text("Uses Apple Intelligence on this Mac. No API key required.")
            }
        }
        .formStyle(.grouped)
        .scenePadding()
    }
}

private struct APIKeyField: View {
    @Binding private var text: String
    @Binding private var isVisible: Bool

    private let title: String
    private let prompt: String

    init(_ title: String, text: Binding<String>, isVisible: Binding<Bool>, prompt: String) {
        self.title = title
        _text = text
        _isVisible = isVisible
        self.prompt = prompt
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Group {
                    if isVisible {
                        TextField(title, text: $text, prompt: Text(prompt))
                    } else {
                        SecureField(title, text: $text, prompt: Text(prompt))
                    }
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(isVisible ? "Hide key" : "Show key")
            }
        }
    }
}
