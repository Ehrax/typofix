import Foundation

struct OpenAICompatibleProvider: LLMProvider {
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let systemPrompt: String
    private let correctionTemperature: Double?

    init(baseURL: URL, apiKey: String, model: String, systemPrompt: String, correctionTemperature: Double? = 0.2) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
        self.correctionTemperature = correctionTemperature
    }

    func correct(_ text: String) async throws -> String {
        try await complete(
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: correctionTemperature
        )
    }

    func rewrite(_ text: String, instruction: String, temperature: Double?) async throws -> String {
        try await complete(
            messages: [
                ChatMessage(role: "system", content: instruction),
                ChatMessage(role: "user", content: text)
            ],
            temperature: temperature
        )
    }

    func rewriteVariants(_ text: String, instruction: String) async throws -> [String] {
        let content = try await complete(
            messages: [
                ChatMessage(role: "system", content: instruction),
                ChatMessage(role: "user", content: text)
            ],
            temperature: nil
        )

        let variants = RewriteVariantParser.parseVariants(from: content)

        guard variants.count == 5 else {
            throw ProviderError.unparseableVariants(reply: content)
        }

        return variants
    }

    private func complete(messages: [ChatMessage], temperature: Double?) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data).error.message
            throw ProviderError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ProviderError.emptyResponse
        }

        guard !content.isEmpty else {
            throw ProviderError.emptyResponse
        }

        return content
    }

}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
}

private struct ErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
