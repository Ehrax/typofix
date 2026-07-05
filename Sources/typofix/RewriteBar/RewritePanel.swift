import AppKit

@MainActor
protocol RewritePanelDelegate: AnyObject {
    func rewritePanelDidRequestClose(_ panel: RewritePanel)
}

final class RewritePanel: NSPanel {
    weak var closeDelegate: RewritePanelDelegate?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func resignKey() {
        super.resignKey()
        closeDelegate?.rewritePanelDidRequestClose(self)
    }
}
