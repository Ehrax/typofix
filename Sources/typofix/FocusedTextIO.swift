import AppKit

@MainActor
struct CapturedFocusedText {
    let text: String
    let pasteboardSnapshot: PasteboardSnapshot
    let previousApplication: NSRunningApplication?
}

@MainActor
enum FocusedTextIO {
    static func captureCurrentFieldText() async throws -> CapturedFocusedText? {
        let previousApplication = NSWorkspace.shared.frontmostApplication
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let originalChangeCount = pasteboard.changeCount

        EventPoster.commandA()
        try await Task.sleep(for: .milliseconds(35))
        EventPoster.commandC()

        let changed = await waitForPasteboardChange(from: originalChangeCount, pasteboard: pasteboard)
        guard changed, let selectedText = pasteboard.string(forType: .string), !selectedText.isEmpty else {
            snapshot.restore(to: pasteboard)
            return nil
        }

        return CapturedFocusedText(
            text: selectedText,
            pasteboardSnapshot: snapshot,
            previousApplication: previousApplication
        )
    }

    static func paste(
        _ text: String,
        restoring snapshot: PasteboardSnapshot,
        previousApplication: NSRunningApplication?
    ) async {
        previousApplication?.activate()
        try? await Task.sleep(for: .milliseconds(80))

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        EventPoster.commandV()
        try? await Task.sleep(for: .milliseconds(180))
        snapshot.restore(to: pasteboard)
    }

    static func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        snapshot.restore(to: .general)
    }

    private static func waitForPasteboardChange(from changeCount: Int, pasteboard: NSPasteboard) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(500))

        while ContinuousClock.now < deadline {
            if pasteboard.changeCount != changeCount {
                try? await Task.sleep(for: .milliseconds(120))
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }

        return false
    }
}
