import AppKit
import Observation

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case shortcuts
    case providers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .providers: return "Providers"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .providers: return "key"
        }
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    private let configStore: ConfigStore
    private var config = TypofixConfig.defaults

    var launchAtLoginDidChange: (() -> Void)?
    var shortcutsDidChange: (() -> Void)?

    private(set) var isLaunchAtLoginEnabled = false
    private(set) var launchAtLoginAvailable = LaunchAtLogin.isAvailable
    private(set) var launchAtLoginErrorMessage: String?

    var isGroqKeyVisible = false
    var isAnthropicKeyVisible = false

    let appleFoundationStatus = AppleFoundationProvider.availabilityDescription

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func load() {
        config = (try? configStore.loadOrCreate()) ?? .defaults
        refreshLaunchAtLoginState()
    }

    // MARK: - Models

    func modelOptions(for role: ModelOption.Role) -> [ModelOption] {
        let selected = selectedOption(for: role)
        var options = ModelCatalog.options(for: role)
        if !options.contains(selected) {
            options.insert(selected, at: 0)
        }
        return options
    }

    private func selectedOption(for role: ModelOption.Role) -> ModelOption {
        switch role {
        case .fast:
            return ModelCatalog.option(providerID: config.provider, modelID: config.model, role: .fast)
        case .smart:
            return ModelCatalog.option(providerID: config.smartProvider, modelID: config.smartModel, role: .smart)
        }
    }

    var fastModelSelectionKey: String {
        get { selectedOption(for: .fast).selectionKey }
        set { applySelection(newValue, role: .fast) }
    }

    var smartModelSelectionKey: String {
        get { selectedOption(for: .smart).selectionKey }
        set { applySelection(newValue, role: .smart) }
    }

    private func applySelection(_ key: String, role: ModelOption.Role) {
        guard let separatorIndex = key.firstIndex(of: "|") else { return }
        let providerID = String(key[..<separatorIndex])
        let modelID = String(key[key.index(after: separatorIndex)...])
        let option = ModelCatalog.option(providerID: providerID, modelID: modelID, role: role)

        switch role {
        case .fast:
            config.provider = option.providerID
            config.model = option.modelID
        case .smart:
            config.smartProvider = option.providerID
            config.smartModel = option.modelID
        }
        persist()
    }

    // MARK: - Shortcuts

    var fastShortcut: HotkeyShortcut { config.fastShortcut }
    var rewriteShortcut: HotkeyShortcut { config.rewriteShortcut }

    func updateFastShortcut(_ newValue: HotkeyShortcut) {
        config.fastShortcut = newValue
        if config.fastShortcut == config.rewriteShortcut, config.fastShortcut != .disabled {
            config.rewriteShortcut = .disabled
        }
        persist()
        shortcutsDidChange?()
    }

    func updateRewriteShortcut(_ newValue: HotkeyShortcut) {
        config.rewriteShortcut = newValue
        if config.rewriteShortcut == config.fastShortcut, config.rewriteShortcut != .disabled {
            config.fastShortcut = .disabled
        }
        persist()
        shortcutsDidChange?()
    }

    // MARK: - Provider keys

    var groqAPIKey: String {
        get { config.apiKey ?? "" }
        set {
            config.apiKey = newValue.nilIfBlank
            config.apiKeyEnvVar = nil
            persist()
        }
    }

    var anthropicAPIKey: String {
        get { config.anthropicApiKey ?? "" }
        set {
            config.anthropicApiKey = newValue.nilIfBlank
            persist()
        }
    }

    // MARK: - Launch at login

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            refreshLaunchAtLoginState()
        } catch {
            refreshLaunchAtLoginState(errorMessage: error.localizedDescription)
        }
        launchAtLoginDidChange?()
    }

    private func refreshLaunchAtLoginState(errorMessage: String? = nil) {
        isLaunchAtLoginEnabled = LaunchAtLogin.isEnabled
        launchAtLoginAvailable = LaunchAtLogin.isAvailable
        launchAtLoginErrorMessage = errorMessage
    }

    // MARK: - Persistence

    private func persist() {
        do {
            try configStore.save(config)
        } catch {
            NSSound.beep()
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
