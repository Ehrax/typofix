import Foundation

struct ProviderDescriptor: Sendable {
    let id: String
    let displayName: String
    let apiKeyConfigKey: String?
    let apiKeyEnvironmentVariable: String?
}

struct ModelOption: Sendable, Equatable {
    enum Role: Sendable, Hashable {
        case fast
        case smart
    }

    let providerID: String
    let modelID: String
    let displayName: String
    let detail: String
    let roles: Set<Role>

    var menuTitle: String {
        "\(displayName) - \(ModelCatalog.providerName(for: providerID))"
    }

    var selectionKey: String {
        "\(providerID)|\(modelID)"
    }
}

enum ModelCatalog {
    static let appleProviderID = "apple"
    static let groqProviderID = "groq"
    static let anthropicProviderID = "anthropic"
    static let appleSystemModelID = "system"

    static let providers: [ProviderDescriptor] = [
        ProviderDescriptor(
            id: groqProviderID,
            displayName: "Groq",
            apiKeyConfigKey: "apiKey",
            apiKeyEnvironmentVariable: TypofixConfig.defaultAPIKeyEnvVar
        ),
        ProviderDescriptor(
            id: anthropicProviderID,
            displayName: "Anthropic",
            apiKeyConfigKey: "anthropicApiKey",
            apiKeyEnvironmentVariable: "ANTHROPIC_API_KEY"
        ),
        ProviderDescriptor(
            id: appleProviderID,
            displayName: "Apple Foundation",
            apiKeyConfigKey: nil,
            apiKeyEnvironmentVariable: nil
        )
    ]

    static let options: [ModelOption] = [
        ModelOption(
            providerID: appleProviderID,
            modelID: appleSystemModelID,
            displayName: "Apple Foundation",
            detail: "Local Apple Intelligence model. No API key.",
            roles: [.fast, .smart]
        ),
        ModelOption(
            providerID: groqProviderID,
            modelID: "openai/gpt-oss-20b",
            displayName: "GPT-OSS 20B",
            detail: "Very fast Groq production model.",
            roles: [.fast, .smart]
        ),
        ModelOption(
            providerID: groqProviderID,
            modelID: "llama-3.1-8b-instant",
            displayName: "Llama 3.1 8B Instant",
            detail: "Fast, cheap Groq production model.",
            roles: [.fast]
        ),
        ModelOption(
            providerID: groqProviderID,
            modelID: "llama-3.3-70b-versatile",
            displayName: "Llama 3.3 70B",
            detail: "Balanced Groq production model.",
            roles: [.fast, .smart]
        ),
        ModelOption(
            providerID: groqProviderID,
            modelID: "openai/gpt-oss-120b",
            displayName: "GPT-OSS 120B",
            detail: "Stronger Groq production model with high throughput.",
            roles: [.smart]
        ),
        ModelOption(
            providerID: groqProviderID,
            modelID: "qwen/qwen3.6-27b",
            displayName: "Qwen3.6 27B",
            detail: "Groq preview model for smart comparisons.",
            roles: [.smart]
        ),
        ModelOption(
            providerID: anthropicProviderID,
            modelID: "claude-haiku-4-5-20251001",
            displayName: "Claude Haiku 4.5",
            detail: "Fastest Claude option.",
            roles: [.fast, .smart]
        ),
        ModelOption(
            providerID: anthropicProviderID,
            modelID: "claude-sonnet-5",
            displayName: "Claude Sonnet 5",
            detail: "Fast Claude smart default.",
            roles: [.smart]
        ),
        ModelOption(
            providerID: anthropicProviderID,
            modelID: "claude-opus-4-8",
            displayName: "Claude Opus 4.8",
            detail: "More capable, usually slower.",
            roles: [.smart]
        ),
    ]

    static func options(for role: ModelOption.Role) -> [ModelOption] {
        options.filter { $0.roles.contains(role) }
    }

    static func option(providerID: String, modelID: String, role: ModelOption.Role) -> ModelOption {
        if let option = options(for: role).first(where: { $0.providerID == providerID && $0.modelID == modelID }) {
            return option
        }

        return ModelOption(
            providerID: providerID,
            modelID: modelID,
            displayName: modelID,
            detail: "Custom model from config.json",
            roles: [role]
        )
    }

    static func providerName(for id: String) -> String {
        providers.first(where: { $0.id == id })?.displayName ?? id
    }
}
