import AppKit

@MainActor
enum EventPoster {
    static func commandA() {
        postCommandKey(virtualKey: 0)
    }

    static func commandC() {
        postCommandKey(virtualKey: 8)
    }

    static func commandV() {
        postCommandKey(virtualKey: 9)
    }

    private static func postCommandKey(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let flags: CGEventFlags = .maskCommand
        let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        down?.flags = flags
        let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
