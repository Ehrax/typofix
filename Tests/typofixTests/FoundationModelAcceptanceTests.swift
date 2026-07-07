import XCTest
@testable import typofix

/// Local-only acceptance tests for Apple's on-device Foundation Models provider.
/// These do not call Groq or Anthropic and do not spend API tokens.
final class FoundationModelAcceptanceTests: XCTestCase {
    private func appleConfig() throws -> TypofixConfig {
        try XCTSkipUnless(AppleFoundationProvider.isAvailable, AppleFoundationProvider.availabilityDescription)
        return TypofixConfig(
            provider: "apple",
            model: ModelCatalog.appleSystemModelID,
            apiKeyEnvVar: nil,
            apiKey: nil,
            smartProvider: "apple",
            smartModel: ModelCatalog.appleSystemModelID,
            anthropicApiKey: nil,
            fastShortcut: HotkeyShortcut.defaultFast,
            rewriteShortcut: HotkeyShortcut.defaultRewrite
        )
    }

    func testAppleFoundationFastCorrection() async throws {
        let provider = try ProviderFactory.makeFastProvider(config: appleConfig())

        let output = try await provider.correct("helo world")

        XCTAssertFalse(output.isEmpty)
        XCTAssertNotEqual(output, "helo world")
        XCTAssertTrue(output.localizedCaseInsensitiveContains("hello"), "expected typo fix; got: \(output)")
    }

    @MainActor
    func testAppleFoundationSmartVariants() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["TYPOFIX_RUN_FOUNDATION_SMART_ACCEPTANCE"] == "1",
            "Apple Foundation smart variants are live/nondeterministic; set TYPOFIX_RUN_FOUNDATION_SMART_ACCEPTANCE=1 to run."
        )

        let provider = try ProviderFactory.makeSmartProvider(config: appleConfig())

        let variants = try await provider.rewriteVariants(
            "kannst du mir bitte morgen die zahlen schicken danke",
            instruction: RewriteBarController.variantsPrompt
        )

        XCTAssertEqual(variants.count, 5, "expected 5 variants; got \(variants.count): \(variants)")
        XCTAssertTrue(variants.allSatisfy { !$0.isEmpty }, "a variant was empty: \(variants)")
    }
}
