import Foundation

protocol LLMProvider: Sendable {
    func correct(_ text: String) async throws -> String
    func rewrite(_ text: String, instruction: String, temperature: Double?) async throws -> String
    func rewriteVariants(_ text: String, instruction: String) async throws -> [String]
}

enum ProviderError: LocalizedError {
    case unsupportedProvider(String)
    case missingAPIKey(String)
    case invalidResponse
    case unparseableVariants(reply: String)
    case httpError(statusCode: Int, message: String?)
    case emptyResponse
    case foundationModelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let provider):
            "Unsupported provider: \(provider)"
        case .missingAPIKey(let name):
            "Missing API key. Set \(name) or add the matching key to config."
        case .invalidResponse:
            "The provider returned an invalid response."
        case .unparseableVariants(let reply):
            "Could not parse 5 rewrite variants from the reply: \(reply.prefix(280))"
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                "HTTP \(statusCode): \(message)"
            } else {
                "HTTP \(statusCode)"
            }
        case .emptyResponse:
            "The provider returned no corrected text."
        case .foundationModelUnavailable(let reason):
            "Apple Foundation model unavailable. \(reason)"
        }
    }
}
