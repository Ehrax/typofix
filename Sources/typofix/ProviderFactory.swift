import Foundation

struct ProviderFactory: Sendable {
    static func makeFastProvider(config: TypofixConfig) throws -> any LLMProvider {
        switch config.provider.lowercased() {
        case "groq":
            return try makeGroqProvider(model: config.model, config: config, roleProviderID: config.provider)
        case "anthropic":
            return try makeAnthropicProvider(model: config.model, config: config, roleProviderID: config.provider)
        case "apple", "apple-foundation", "foundation":
            return AppleFoundationProvider(
                systemPrompt: PromptCatalog.fastCorrectionPrompt(providerID: config.provider, modelID: config.model),
                correctionTemperature: PromptCatalog.correctionTemperature(providerID: config.provider, modelID: config.model)
            )
        default:
            throw ProviderError.unsupportedProvider(config.provider)
        }
    }

    static func makeSmartProvider(config: TypofixConfig) throws -> any LLMProvider {
        switch config.smartProvider.lowercased() {
        case "anthropic":
            return try makeAnthropicProvider(model: config.smartModel, config: config, roleProviderID: config.smartProvider)
        case "groq":
            return try makeGroqProvider(model: config.smartModel, config: config, roleProviderID: config.smartProvider)
        case "apple", "apple-foundation", "foundation":
            return AppleFoundationProvider(
                systemPrompt: PromptCatalog.fastCorrectionPrompt(providerID: config.smartProvider, modelID: config.smartModel),
                correctionTemperature: PromptCatalog.correctionTemperature(providerID: config.smartProvider, modelID: config.smartModel)
            )
        default:
            throw ProviderError.unsupportedProvider(config.smartProvider)
        }
    }

    private static func makeGroqProvider(model: String, config: TypofixConfig, roleProviderID: String) throws -> OpenAICompatibleProvider {
        let keyName = config.apiKeyEnvVar ?? TypofixConfig.defaultAPIKeyEnvVar
        let apiKey = config.apiKey?.nilIfBlank
            ?? ProcessInfo.processInfo.environment[keyName]?.nilIfBlank
            ?? ProcessInfo.processInfo.environment[TypofixConfig.defaultAPIKeyEnvVar]?.nilIfBlank

        guard let apiKey else {
            throw ProviderError.missingAPIKey(keyName)
        }

        return OpenAICompatibleProvider(
            baseURL: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
            apiKey: apiKey,
            model: model,
            systemPrompt: PromptCatalog.fastCorrectionPrompt(providerID: roleProviderID, modelID: model),
            correctionTemperature: PromptCatalog.correctionTemperature(providerID: roleProviderID, modelID: model)
        )
    }

    private static func makeAnthropicProvider(model: String, config: TypofixConfig, roleProviderID: String) throws -> OpenAICompatibleProvider {
        let apiKey = config.anthropicApiKey?.nilIfBlank
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.nilIfBlank

        guard let apiKey else {
            throw ProviderError.missingAPIKey("ANTHROPIC_API_KEY")
        }

        return OpenAICompatibleProvider(
            baseURL: URL(string: "https://api.anthropic.com/v1/chat/completions")!,
            apiKey: apiKey,
            model: model,
            systemPrompt: PromptCatalog.fastCorrectionPrompt(providerID: roleProviderID, modelID: model),
            correctionTemperature: PromptCatalog.correctionTemperature(providerID: roleProviderID, modelID: model)
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
