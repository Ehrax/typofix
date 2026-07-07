import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let configStore = ConfigStore()
    let menuBarState = MenuBarState()
    private var feedback: StatusFeedback?
    private var correctionController: CorrectionController?
    private var rewriteBarController: RewriteBarController?
    private var fastHotkeyMonitor: HotkeyMonitor?
    private var rewriteHotkeyMonitor: HotkeyMonitor?
    private let operationGate = OperationGate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        feedback = StatusFeedback(state: menuBarState, normalTitle: "Tx")
        _ = AccessibilityPermission.requestIfNeeded()

        do {
            let config = try configStore.loadOrCreate()
            guard let feedback else { return }
            correctionController = CorrectionController(
                configStore: configStore,
                feedback: feedback,
                operationGate: operationGate
            )
            rewriteBarController = RewriteBarController(
                configStore: configStore,
                operationGate: operationGate
            )
            startHotkeyMonitors(config: config)
        } catch {
            feedback?.showWarning()
        }
    }

    func fixCurrentInputFromMenu() {
        correctionController?.trigger()
    }

    func openConfigFromMenu() {
        do {
            _ = try configStore.loadOrCreate()
            NSWorkspace.shared.open(configStore.configURL)
        } catch {
            feedback?.showWarning()
        }
    }

    func settingsLaunchAtLoginDidChange() {
        updateLaunchAtLoginMenuItem()
    }

    func settingsShortcutsDidChange() {
        reloadHotkeyMonitors()
    }

    func quitFromMenu() {
        NSApp.terminate(nil)
    }

    func refreshAccessibilityStatusFromMenu() {
        _ = AccessibilityPermission.requestIfNeeded()
    }

    func setLaunchAtLoginFromMenu(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            updateLaunchAtLoginMenuItem()
        } catch {
            updateLaunchAtLoginMenuItem(errorMessage: error.localizedDescription)
        }
    }

    private func updateLaunchAtLoginMenuItem(errorMessage: String? = nil) {
        menuBarState.launchAtLoginErrorMessage = errorMessage
    }

    private func reloadHotkeyMonitors() {
        do {
            startHotkeyMonitors(config: try configStore.loadOrCreate())
        } catch {
            feedback?.showWarning()
        }
    }

    private func startHotkeyMonitors(config: TypofixConfig) {
        fastHotkeyMonitor?.stop()
        rewriteHotkeyMonitor?.stop()
        fastHotkeyMonitor = nil
        rewriteHotkeyMonitor = nil

        if let modifier = config.fastShortcut.modifier {
            let monitor = HotkeyMonitor(modifier: modifier) { [weak self] in
                self?.correctionController?.trigger()
            }
            monitor.start()
            fastHotkeyMonitor = monitor
        }

        guard config.rewriteShortcut != config.fastShortcut else {
            return
        }

        if let modifier = config.rewriteShortcut.modifier {
            let monitor = HotkeyMonitor(modifier: modifier) { [weak self] in
                self?.rewriteBarController?.trigger()
            }
            monitor.start()
            rewriteHotkeyMonitor = monitor
        }
    }
}
