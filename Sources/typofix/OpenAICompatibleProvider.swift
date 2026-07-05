import Foundation

struct OpenAICompatibleProvider: LLMProvider {
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let systemPrompt: String

    init(baseURL: URL, apiKey: String, model: String, systemPrompt: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
    }

    func correct(_ text: String) async throws -> String {
        try await complete(
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.2,
            maxTokens: Self.maxTokens(for: text)
        )
    }

    func rewrite(_ text: String, instruction: String, temperature: Double?) async throws -> String {
        try await complete(
            messages: [
                ChatMessage(role: "system", content: instruction),
                ChatMessage(role: "user", content: text)
            ],
            temperature: temperature,
            maxTokens: Self.maxTokens(for: text, completionPadding: 1024)
        )
    }

    func rewriteVariants(_ text: String, instruction: String) async throws -> [String] {
        let content = try await complete(
            messages: [
                ChatMessage(role: "system", content: instruction),
                ChatMessage(role: "user", content: text)
            ],
            temperature: nil,
            maxTokens: Self.variantMaxTokens(for: text)
        )

        let stripped = Self.stripMarkdownFences(from: content)
        let data = Data(stripped.utf8)
        let variants = try JSONDecoder().decode([String].self, from: data)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard variants.count == 5 else {
            throw ProviderError.invalidResponse
        }

        return variants
    }

    private func complete(messages: [ChatMessage], temperature: Double?, maxTokens: Int) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
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

    private static func maxTokens(for text: String, completionPadding: Int = 256) -> Int {
        let estimatedInputTokens = max(64, text.count / 3)
        return min(4096, max(256, estimatedInputTokens + completionPadding))
    }

    private static func variantMaxTokens(for text: String) -> Int {
        let estimatedInputTokens = max(64, text.count / 3)
        return min(8192, max(1024, estimatedInputTokens * 5 + 1024))
    }

    private static func stripMarkdownFences(from content: String) -> String {
        var stripped = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.hasPrefix("```") else { return stripped }

        if let firstLineEnd = stripped.firstIndex(of: "\n") {
            stripped = String(stripped[stripped.index(after: firstLineEnd)...])
        }

        if let closingFence = stripped.range(of: "```", options: .backwards) {
            stripped = String(stripped[..<closingFence.lowerBound])
        }

        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
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
