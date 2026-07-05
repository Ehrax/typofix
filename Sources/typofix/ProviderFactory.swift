import Foundation

struct ProviderFactory: Sendable {
    static func makeFastProvider(config: TypofixConfig) throws -> any LLMProvider {
        switch config.provider.lowercased() {
        case "groq":
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
                model: config.model,
                systemPrompt: Self.fastSystemPrompt
            )
        default:
            throw ProviderError.unsupportedProvider(config.provider)
        }
    }

    static func makeSmartProvider(config: TypofixConfig) throws -> any LLMProvider {
        switch config.smartProvider.lowercased() {
        case "anthropic":
            let apiKey = config.anthropicApiKey?.nilIfBlank
                ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.nilIfBlank

            guard let apiKey else {
                throw ProviderError.missingAPIKey("ANTHROPIC_API_KEY")
            }

            return OpenAICompatibleProvider(
                baseURL: URL(string: "https://api.anthropic.com/v1/chat/completions")!,
                apiKey: apiKey,
                model: config.smartModel,
                systemPrompt: Self.fastSystemPrompt
            )
        case "groq":
            let fastConfig = TypofixConfig(
                provider: "groq",
                model: config.smartModel,
                apiKeyEnvVar: config.apiKeyEnvVar,
                apiKey: config.apiKey,
                smartProvider: config.smartProvider,
                smartModel: config.smartModel,
                anthropicApiKey: config.anthropicApiKey
            )
            return try makeFastProvider(config: fastConfig)
        default:
            throw ProviderError.unsupportedProvider(config.smartProvider)
        }
    }

    private static let fastSystemPrompt = """
    Fix spelling, grammar, and typos only. Preserve the original meaning, tone, language, formatting, and line breaks. The text may be German or English. Return ONLY the corrected text, with no quotes and no commentary.
    """
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
