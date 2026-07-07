# Typofix

**Fix typos anywhere on your Mac with a double-tap. Rewrite anything with a Spotlight-style bar.**

Typofix is a tiny macOS menu bar app that works in *any* text field — Slack, Mail, your browser, anywhere you type:

- **Shift Shift (double-tap Shift)** — instantly fixes spelling, grammar, and typos in the current field. Sub-second, silent, keeps your tone.
- **⌥ ⌥ (double-tap Option)** — opens a Spotlight-style rewrite bar with five variants of what you wrote: **Auf den Punkt** (tightened), **Polished**, **Kürzer**, **Freundlicher**, **Formeller** — plus a free-text instruction field ("mach es freundlicher"). Pick with `1–5`, arrows, or `Ctrl+J/K`, hit Enter, done.

Works great in German and English. Your voice is preserved — smileys, casual register, and all. `:D`

<!-- ![Rewrite bar](docs/rewrite-bar.png) -->

## Install

1. Download the latest `Typofix-x.y.z.zip` from [Releases](https://github.com/Ehrax/typofix/releases), unzip, and drag `Typofix.app` to `/Applications`. The app is signed and notarized — it just opens.
2. Launch it. Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility) — Typofix needs it to read and replace the text field you're editing.
3. Click the `Tx` menu bar icon → **Settings…**:
   - **General** chooses the fast typo-fix model and the smart rewrite model.
   - **Shortcuts** configures the double-tap shortcuts for fast fix and the rewrite bar.
   - **Providers** stores Groq and Anthropic API keys. Apple Foundation is available without a key when Apple Intelligence is enabled on the Mac.
4. Optional: enable **Launch at Login** from the `Tx` menu or Settings.

Requires macOS 26 (Tahoe) or later.

## How it works

Typofix simulates ⌘A/⌘C to capture your current field, sends the text to an LLM with a strict "fix, don't change" prompt, pastes the result back, and restores your clipboard. No accounts, no telemetry, no server of ours — your text goes only to the LLM provider you configure, and your keys stay in `~/.config/typofix/config.json` on your machine.

The rewrite prompt is hardened: your text is treated as content, never as instructions; emojis, URLs, names, and numbers are preserved verbatim; casual register is never escalated (except in the deliberate "Formeller" variant).

## Configuration

Settings UI covers the common cases. The underlying JSON at `~/.config/typofix/config.json`:

```json
{
  "provider": "groq",
  "model": "openai/gpt-oss-20b",
  "apiKey": "gsk_…",
  "smartProvider": "anthropic",
  "smartModel": "claude-sonnet-5",
  "anthropicApiKey": "sk-ant-…",
  "fastShortcut": "doubleShift",
  "rewriteShortcut": "doubleOption"
}
```

Keys can alternatively come from `GROQ_API_KEY` / `ANTHROPIC_API_KEY` environment variables.

### Swapping providers or models

Both paths use a small `LLMProvider` protocol, so switching models is a settings change and adding a provider (Gemini, Cerebras, a local Ollama…) is a few lines in `ProviderFactory`. Supported provider IDs are:

- `groq` for Groq OpenAI-compatible chat completions.
- `anthropic` for Anthropic's OpenAI SDK compatibility endpoint.
- `apple` for the local Apple Foundation model.

```swift
protocol LLMProvider {
    func correct(_ text: String) async throws -> String
    func rewrite(_ text: String, instruction: String, temperature: Double?) async throws -> String
    func rewriteVariants(_ text: String, instruction: String) async throws -> [String]
}
```

## Building from source

Swift Package Manager only — no Xcode project, zero dependencies:

```sh
swift run typofix          # dev run (grant Accessibility to your terminal)
Scripts/build-app.sh       # release: builds, signs, notarizes*, zips dist/Typofix.app
```

\* Signing uses the first `Developer ID Application` identity in your keychain and notarizes via the `typofix-notary` keychain profile; without them it falls back to ad-hoc signing (then use right-click → Open on first launch).

## Roadmap

See [open issues](https://github.com/Ehrax/typofix/issues) — next up: style memory (it learns how *you* write from the variants you pick) and a proper app icon.

Contributions and issue reports welcome.

## License

[MIT](LICENSE)
