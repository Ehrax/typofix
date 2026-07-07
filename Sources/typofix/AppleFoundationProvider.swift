import Foundation
import FoundationModels

struct AppleFoundationProvider: LLMProvider {
    private let systemPrompt: String
    private let correctionTemperature: Double?

    init(systemPrompt: String, correctionTemperature: Double? = 0.2) {
        self.systemPrompt = systemPrompt
        self.correctionTemperature = correctionTemperature
    }

    func correct(_ text: String) async throws -> String {
        try await complete(text, instructions: systemPrompt, temperature: correctionTemperature)
    }

    func rewrite(_ text: String, instruction: String, temperature: Double?) async throws -> String {
        try await complete(text, instructions: instruction, temperature: temperature)
    }

    func rewriteVariants(_ text: String, instruction: String) async throws -> [String] {
        let content = try await complete(text, instructions: instruction, temperature: nil)
        let variants = RewriteVariantParser.parseVariants(from: content)

        guard variants.count == 5 else {
            throw ProviderError.unparseableVariants(reply: content)
        }

        return variants
    }

    static var availabilityDescription: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "Unavailable: device is not eligible for Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Unavailable: Apple Intelligence is not enabled"
        case .unavailable(.modelNotReady):
            return "Unavailable: model is not ready yet"
        case .unavailable(let reason):
            return "Unavailable: \(String(describing: reason))"
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    private func complete(_ prompt: String, instructions: String, temperature: Double?) async throws -> String {
        guard Self.isAvailable else {
            throw ProviderError.foundationModelUnavailable(Self.availabilityDescription)
        }

        let session = LanguageModelSession(instructions: instructions)
        let response: LanguageModelSession.Response<String>

        if let temperature {
            response = try await session.respond(to: prompt, options: GenerationOptions(temperature: temperature))
        } else {
            response = try await session.respond(to: prompt)
        }

        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw ProviderError.emptyResponse
        }

        return content
    }
}
