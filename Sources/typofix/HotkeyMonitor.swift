import AppKit

@MainActor
final class HotkeyMonitor {
    private let modifier: NSEvent.ModifierFlags
    private let onTrigger: @MainActor () -> Void
    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var modifierDownStartedAt: ContinuousClock.Instant?
    private var lastIsolatedModifierTapAt: ContinuousClock.Instant?
    private var invalidatedCurrentPress = false

    init(modifier: NSEvent.ModifierFlags, onTrigger: @escaping @MainActor () -> Void) {
        self.modifier = modifier
        self.onTrigger = onTrigger
    }

    func start() {
        stop()

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            Task { @MainActor in
                self?.handleKeyDown()
            }
        }
    }

    func stop() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        modifierDownStartedAt = nil
        lastIsolatedModifierTapAt = nil
        invalidatedCurrentPress = false
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let activeFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifierOnly = activeFlags == modifier
        let modifierIsDown = activeFlags.contains(modifier)

        if modifierOnly, modifierDownStartedAt == nil {
            modifierDownStartedAt = .now
            invalidatedCurrentPress = false
            return
        }

        if !modifierIsDown, let startedAt = modifierDownStartedAt {
            defer {
                modifierDownStartedAt = nil
                invalidatedCurrentPress = false
            }

            guard !invalidatedCurrentPress else { return }

            let now = ContinuousClock.now
            guard startedAt.duration(to: now) <= .milliseconds(350) else {
                return
            }

            if let lastTap = lastIsolatedModifierTapAt, lastTap.duration(to: now) <= .milliseconds(350) {
                lastIsolatedModifierTapAt = nil
                onTrigger()
            } else {
                lastIsolatedModifierTapAt = now
            }
        }

        if modifierIsDown && !modifierOnly {
            invalidatedCurrentPress = true
        }
    }

    private func handleKeyDown() {
        if modifierDownStartedAt != nil {
            invalidatedCurrentPress = true
        }
        lastIsolatedModifierTapAt = nil
    }
}
