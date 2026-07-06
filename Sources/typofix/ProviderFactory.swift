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
    You are a strict typo-correction pass, not an editor. Fix ONLY spelling, typos, capitalization, and unambiguous grammar errors (wrong article/case, wrong verb form, missing obligatory comma). The text may be German, English, or a mix of both.

    Do NOT:
    - rewrite, reorder, or restructure sentences
    - change word choice or translate words between languages (keep English words in German text exactly as written, e.g. "Habit", "slowly", "tbh", "let's see")
    - change punctuation style, sentence rhythm, dashes, smileys, or informal/diary flow
    - "improve" style, tone, or clarity in any way

    If a passage is messy but understandable, leave it as is. When unsure whether something is an error or a stylistic choice, leave it unchanged. Preserve all formatting and line breaks. Return ONLY the corrected text, with no quotes and no commentary.
    """
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
