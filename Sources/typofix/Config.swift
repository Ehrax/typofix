import Foundation

struct TypofixConfig: Codable, Sendable {
    var provider: String
    var model: String
    var apiKeyEnvVar: String?
    var apiKey: String?
    var smartProvider: String
    var smartModel: String
    var anthropicApiKey: String?
    var fastShortcut: HotkeyShortcut
    var rewriteShortcut: HotkeyShortcut

    static let defaultProvider = "groq"
    static let defaultModel = "openai/gpt-oss-20b"
    static let defaultAPIKeyEnvVar = "GROQ_API_KEY"
    static let defaultSmartProvider = "anthropic"
    static let defaultSmartModel = "claude-sonnet-5"

    static var defaults: TypofixConfig {
        TypofixConfig(
            provider: defaultProvider,
            model: defaultModel,
            apiKeyEnvVar: nil,
            apiKey: nil,
            smartProvider: defaultSmartProvider,
            smartModel: defaultSmartModel,
            anthropicApiKey: nil,
            fastShortcut: HotkeyShortcut.defaultFast,
            rewriteShortcut: HotkeyShortcut.defaultRewrite
        )
    }

    init(
        provider: String,
        model: String,
        apiKeyEnvVar: String?,
        apiKey: String?,
        smartProvider: String,
        smartModel: String,
        anthropicApiKey: String?,
        fastShortcut: HotkeyShortcut = HotkeyShortcut.defaultFast,
        rewriteShortcut: HotkeyShortcut = HotkeyShortcut.defaultRewrite
    ) {
        self.provider = provider
        self.model = model
        self.apiKeyEnvVar = apiKeyEnvVar
        self.apiKey = apiKey
        self.smartProvider = smartProvider
        self.smartModel = smartModel
        self.anthropicApiKey = anthropicApiKey
        self.fastShortcut = fastShortcut
        self.rewriteShortcut = rewriteShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? Self.defaultProvider
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? Self.defaultModel
        self.apiKeyEnvVar = try container.decodeIfPresent(String.self, forKey: .apiKeyEnvVar)
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        self.smartProvider = try container.decodeIfPresent(String.self, forKey: .smartProvider) ?? Self.defaultSmartProvider
        self.smartModel = try container.decodeIfPresent(String.self, forKey: .smartModel) ?? Self.defaultSmartModel
        self.anthropicApiKey = try container.decodeIfPresent(String.self, forKey: .anthropicApiKey)
        self.fastShortcut = try container.decodeIfPresent(HotkeyShortcut.self, forKey: .fastShortcut) ?? HotkeyShortcut.defaultFast
        self.rewriteShortcut = try container.decodeIfPresent(HotkeyShortcut.self, forKey: .rewriteShortcut) ?? HotkeyShortcut.defaultRewrite
    }
}

struct ConfigStore: Sendable {
    let configURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configURL = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("typofix", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    func loadOrCreate() throws -> TypofixConfig {
        let directory = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: configURL.path) {
            try save(.defaults)
            return .defaults
        }

        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(TypofixConfig.self, from: data)
    }

    func save(_ config: TypofixConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: [.atomic])
    }
}
