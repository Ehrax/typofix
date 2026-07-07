import SwiftUI

struct SettingsRootView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 230)
        } detail: {
            switch selection ?? .general {
            case .general:
                GeneralSettingsView(viewModel: viewModel)
            case .shortcuts:
                ShortcutsSettingsView(viewModel: viewModel)
            case .providers:
                ProvidersSettingsView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 420, idealHeight: 460)
        .toolbar(removing: .sidebarToggle)
        .toolbar(.hidden, for: .windowToolbar)
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
                .help(viewModel.launchAtLoginAvailable ? "Open Typofix automatically when you sign in." : LaunchAtLogin.unavailableTooltip)

                if let errorMessage = viewModel.launchAtLoginErrorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("System")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(SettingsSection.general.title)
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
        .navigationTitle(SettingsSection.shortcuts.title)
    }
}

private struct ProvidersSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Groq") {
                    APIKeyField(
                        text: $viewModel.groqAPIKey,
                        isVisible: $viewModel.isGroqKeyVisible,
                        placeholder: "GROQ_API_KEY or config.json"
                    )
                }
                LabeledContent("Anthropic") {
                    APIKeyField(
                        text: $viewModel.anthropicAPIKey,
                        isVisible: $viewModel.isAnthropicKeyVisible,
                        placeholder: "ANTHROPIC_API_KEY or config.json"
                    )
                }
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
        .navigationTitle(SettingsSection.providers.title)
    }
}

private struct APIKeyField: View {
    @Binding var text: String
    @Binding var isVisible: Bool
    let placeholder: String

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)

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
