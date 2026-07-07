import Foundation

enum RewriteVariantParser {
    /// Decode the model's reply into strings, tolerating a stray preamble or
    /// missing/partial fences: try the fence-stripped content first, then fall
    /// back to the `[ ... ]` array extracted from anywhere in the reply.
    static func parseVariants(from content: String) -> [String] {
        let stripped = stripMarkdownFences(from: content)
        for candidate in [stripped, extractJSONArray(from: stripped)].compactMap({ $0 }) {
            if let decoded = try? JSONDecoder().decode([String].self, from: Data(candidate.utf8)) {
                return decoded
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        return parseNumberedList(from: stripped)
    }

    private static func extractJSONArray(from content: String) -> String? {
        guard let start = content.firstIndex(of: "["),
              let end = content.lastIndex(of: "]"),
              start < end else { return nil }
        return String(content[start...end])
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

    private static func parseNumberedList(from content: String) -> [String] {
        content
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let first = trimmed.first, first.isNumber else { return nil }

                let afterNumber = trimmed.drop(while: { $0.isNumber })
                guard let separator = afterNumber.first, separator == "." || separator == ")" else {
                    return nil
                }

                let value = afterNumber
                    .dropFirst()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
    }
}
