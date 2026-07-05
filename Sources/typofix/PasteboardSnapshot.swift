import AppKit

@MainActor
struct PasteboardSnapshot {
    private let string: String?

    init(pasteboard: NSPasteboard = .general) {
        self.string = pasteboard.string(forType: .string)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        if let string {
            pasteboard.setString(string, forType: .string)
        }
    }
}
