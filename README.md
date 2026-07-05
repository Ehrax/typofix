# typofix

`typofix` is a macOS 26+ menu bar utility that fixes or rewrites the text field you are currently editing. It selects the current input, copies it, sends the text to an LLM, pastes the chosen result back, then restores your previous string clipboard contents on a best-effort basis.

It is a Swift Package Manager executable only: no Xcode project and no external dependencies.

## Run

```sh
export GROQ_API_KEY="your-groq-api-key"
export ANTHROPIC_API_KEY="your-anthropic-api-key"
swift run typofix
```

On first launch, typofix creates:

```text
~/.config/typofix/config.json
```

## Usage

Use the menu bar item `Tx` and choose `Fix current input`, or double-tap the Command key. The hotkey is two isolated Command presses within 350 ms. If another key is pressed while Command is down, the sequence is cancelled. This instant-fix flow is the fast path and keeps using `provider`, `model`, and `apiKey`.

Double-tap Option to open the Spotlight-style rewrite bar. It captures the current field text and shows two smart variants:

- `Auf den Punkt`: tightens the text, cutting filler and redundancy while preserving voice, language, greetings, and sign-offs.
- `Polished`: fixes grammar and improves flow while preserving meaning, tone, and language.

Use Up/Down, Ctrl+J/K, or keys `1`, `2`, and `3` to select a variant, Enter to paste the selected result, and Esc to close without changing the field. Type a custom instruction in the bottom field and press Enter to request a third variant; a new instruction replaces the previous instruction result.

macOS may reserve double-Command for Siri. Disable that shortcut in System Settings before relying on the typofix hotkey.

Choose `Settings…` from the `Tx` menu to edit models and API keys. `Cmd+,` also opens settings while a Typofix window is key. Changes are saved to `~/.config/typofix/config.json` and apply on the next fix or rewrite trigger. `Open config` remains available in the menu for direct JSON editing.

## Accessibility Permission

typofix posts keyboard events for Command-A, Command-C, and Command-V, so macOS Accessibility permission is required. The app prompts on launch and shows the current status in the menu. If permission is missing, open System Settings and allow typofix under Privacy & Security > Accessibility.

## Release And Install

Build the app bundle and zip:

```sh
Scripts/build-app.sh
```

The script creates `dist/Typofix.app` and `dist/Typofix-0.1.0.zip`. It signs with the first available `Developer ID Application` identity in your keychain, or uses ad-hoc signing if no Developer ID identity is available.

To install, drag `dist/Typofix.app` to `/Applications` and launch it from there. Grant Accessibility permission to `Typofix.app` itself in System Settings > Privacy & Security > Accessibility. For unsigned or ad-hoc builds, Gatekeeper may require right-clicking `Typofix.app` and choosing Open the first time.

## Config

The config file is JSON:

```json
{
  "anthropicApiKey": null,
  "apiKey": null,
  "apiKeyEnvVar": null,
  "model": "llama-3.1-8b-instant",
  "provider": "groq",
  "smartModel": "claude-sonnet-5",
  "smartProvider": "anthropic"
}
```

Fast-path API key resolution order:

1. `apiKey` in the config file.
2. The configured `apiKeyEnvVar`, if set.
3. `GROQ_API_KEY`.

Smart rewrite API key resolution order:

1. `anthropicApiKey` in the config file.
2. `ANTHROPIC_API_KEY`.

If no smart key is available, the rewrite bar opens and shows `Add anthropicApiKey to config` instead of crashing.

The default fast provider is `groq`, using Groq's OpenAI-compatible chat completions endpoint:

```text
https://api.groq.com/openai/v1/chat/completions
```

The default smart provider is `anthropic`, using Anthropic's OpenAI-compatible chat completions endpoint:

```text
https://api.anthropic.com/v1/chat/completions
```

## Swapping Providers Or Models

Change `model` to use a different fast model, or `smartModel` to use a different rewrite model. Provider construction is isolated behind `ProviderFactory`, and the runtime depends on the `LLMProvider` protocol:

```swift
protocol LLMProvider {
    func correct(_ text: String) async throws -> String
    func rewrite(_ text: String, instruction: String, temperature: Double) async throws -> String
}
```

Groq and Anthropic are both backed by `OpenAICompatibleProvider(baseURL:apiKey:model:systemPrompt:)`. To add another OpenAI-compatible provider, add a provider name in `ProviderFactory` and update `provider` or `smartProvider` in the config.
