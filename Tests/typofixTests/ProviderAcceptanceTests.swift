import XCTest
@testable import typofix

/// Live acceptance tests. These hit the real Groq + Anthropic endpoints using
/// the keys in ~/.config/typofix/config.json, exercising the actual provider
/// code paths (not a reimplementation). They skip if no keys are configured.
///
/// Run with:  swift test
final class ProviderAcceptanceTests: XCTestCase {

    private func loadConfigOrSkip() throws -> TypofixConfig {
        let config = try ConfigStore().loadOrCreate()
        try XCTSkipIf((config.apiKey ?? "").isEmpty, "no Groq API key configured")
        try XCTSkipIf((config.anthropicApiKey ?? "").isEmpty, "no Anthropic API key configured")
        return config
    }

    // ⌘⌘ path: fast typo correction must return non-empty, changed text.
    func testFastCorrectionFixesTypos() async throws {
        let config = try loadConfigOrSkip()
        let provider = try ProviderFactory.makeFastProvider(config: config)

        let input = "hey zusammen, ich hab die neue version heute deployt und es laueft soweit alles stabiel."
        let output = try await provider.correct(input)

        XCTAssertFalse(output.isEmpty, "correction returned empty")
        XCTAssertNotEqual(output, input, "correction left the text unchanged despite typos")
        XCTAssertTrue(output.contains("läuft"), "expected 'laueft' -> 'läuft'; got: \(output)")
    }

    // ⌥⌥ path: the rewrite bar must get exactly 5 parseable variants — short input.
    @MainActor
    func testRewriteVariantsShortInput() async throws {
        let config = try loadConfigOrSkip()
        let provider = try ProviderFactory.makeSmartProvider(config: config)

        let variants = try await provider.rewriteVariants(
            "kannst du mir bitte bis morgen die zahlen schicken danke",
            instruction: RewriteBarController.variantsPrompt
        )

        XCTAssertEqual(variants.count, 5, "expected 5 variants; got \(variants.count): \(variants)")
        XCTAssertTrue(variants.allSatisfy { !$0.isEmpty }, "a variant was empty: \(variants)")
    }

    // ⌥⌥ path with a long, messy paragraph — the case most likely to blow the
    // max_tokens budget and truncate the JSON array (the suspected regression).
    @MainActor
    func testRewriteVariantsLongInput() async throws {
        let config = try loadConfigOrSkip()
        let provider = try ProviderFactory.makeSmartProvider(config: config)

        let input = """
        hey zusammen, kurzes update zum projekt. ich hab die neue version heute \
        deployt und es laueft soweit alles stabiel. hab noch ein paar kleiner bugs \
        gefixt die mir aufgefallen sind, unter anderem das ding mit dem dashbord das \
        immer wieder gecrasht ist wenn man zu schnell geklickt hat. morgen schau ich \
        mir dann nochmal die performance an, da laueft glaub ich noch was nicht ganz \
        rund bei den grossen abfragen. lasst mich wissen ob ihr noch feedback habt \
        oder ob ich irgendwo was uebersehen hab, danke euch :)
        """

        let variants = try await provider.rewriteVariants(
            input,
            instruction: RewriteBarController.variantsPrompt
        )

        XCTAssertEqual(
            variants.count, 5,
            "long input should still yield 5 variants — likely max_tokens truncation if not. got \(variants.count)"
        )
        XCTAssertTrue(variants.allSatisfy { !$0.isEmpty }, "a variant was empty: \(variants)")
    }

    // ⌥⌥ path with a full journal-sized entry (~4k chars). 5 rewrites of this
    // length can exceed the max_tokens budget and truncate the JSON — the most
    // likely cause of a real-world "invalid response".
    @MainActor
    func testRewriteVariantsJournalSizedInput() async throws {
        let config = try loadConfigOrSkip()
        let provider = try ProviderFactory.makeSmartProvider(config: config)

        let paragraph = """
        heute war echt ein voller tag, ich hab morgens direkt nach dem daily meeting \
        angefangen an dem neuen feature zu arbeiten und bin dann irgendwie in ein \
        richtiges rabbit hole gerutscht weil eine sache nicht so lief wie ich dachte. \
        zwischendrin hatte ich noch ein paar calls und musste dringend ein paar bugs \
        fixen die seit gestern rumlagen, unter anderem das ding mit dem dashbord das \
        immer gecrasht ist.
        """
        let input = Array(repeating: paragraph, count: 10).joined(separator: "\n\n")
        XCTAssertGreaterThan(input.count, 3500, "test input should be journal-sized")

        let variants = try await provider.rewriteVariants(
            input,
            instruction: RewriteBarController.variantsPrompt
        )

        XCTAssertEqual(
            variants.count, 5,
            "journal-sized input did not yield 5 variants (\(variants.count)) — likely max_tokens truncation of the JSON array"
        )
    }
}
