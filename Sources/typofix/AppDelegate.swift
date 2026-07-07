import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let configStore = ConfigStore()
    private var statusItem: NSStatusItem?
    private var feedback: StatusFeedback?
    private var correctionController: CorrectionController?
    private var rewriteBarController: RewriteBarController?
    private var settingsWindowController: SettingsWindowController?
    private var fastHotkeyMonitor: HotkeyMonitor?
    private var rewriteHotkeyMonitor: HotkeyMonitor?
    private var accessibilityItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var launchAtLoginErrorItem: NSMenuItem?
    private let operationGate = OperationGate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        setupMenuBar()
        _ = AccessibilityPermission.requestIfNeeded()
        updateAccessibilityMenuItem()

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

    @objc private func fixCurrentInput() {
        correctionController?.trigger()
    }

    @objc private func openConfig() {
        do {
            _ = try configStore.loadOrCreate()
            NSWorkspace.shared.open(configStore.configURL)
        } catch {
            feedback?.showWarning()
        }
    }

    @objc private func openSettings() {
        let controller = settingsWindowController ?? SettingsWindowController(configStore: configStore)
        controller.launchAtLoginDidChange = { [weak self] in
            self?.updateLaunchAtLoginMenuItem()
        }
        controller.shortcutsDidChange = { [weak self] in
            self?.reloadHotkeyMonitors()
        }
        settingsWindowController = controller
        controller.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func refreshAccessibilityStatus() {
        updateAccessibilityMenuItem()
    }

    @objc private func toggleLaunchAtLogin() {
        let requestedState = !LaunchAtLogin.isEnabled

        do {
            try LaunchAtLogin.setEnabled(requestedState)
            updateLaunchAtLoginMenuItem()
        } catch {
            updateLaunchAtLoginMenuItem(errorMessage: error.localizedDescription)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateLaunchAtLoginMenuItem()
        updateAccessibilityMenuItem()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Tx"
        item.button?.toolTip = "Typofix"

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Fix current input", action: #selector(fixCurrentInput), keyEquivalent: ""))
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Open config", action: #selector(openConfig), keyEquivalent: ""))
        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.addItem(launchAtLogin)
        launchAtLoginItem = launchAtLogin

        let launchAtLoginError = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        launchAtLoginError.isEnabled = false
        launchAtLoginError.isHidden = true
        menu.addItem(launchAtLoginError)
        launchAtLoginErrorItem = launchAtLoginError

        menu.addItem(.separator())

        let accessibility = NSMenuItem(title: "", action: #selector(refreshAccessibilityStatus), keyEquivalent: "")
        menu.addItem(accessibility)
        accessibilityItem = accessibility

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
        feedback = StatusFeedback(item: item, normalTitle: "Tx")
        updateLaunchAtLoginMenuItem()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Typofix", action: #selector(quit), keyEquivalent: "q"))

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func updateAccessibilityMenuItem() {
        let trusted = AccessibilityPermission.isTrusted
        accessibilityItem?.title = trusted
            ? "Accessibility: allowed"
            : "Accessibility: required for typing"
        accessibilityItem?.isEnabled = !trusted
    }

    private func updateLaunchAtLoginMenuItem(errorMessage: String? = nil) {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
        launchAtLoginItem?.isEnabled = LaunchAtLogin.isAvailable
        launchAtLoginItem?.toolTip = LaunchAtLogin.isAvailable ? nil : LaunchAtLogin.unavailableTooltip

        launchAtLoginErrorItem?.title = errorMessage ?? ""
        launchAtLoginErrorItem?.isHidden = errorMessage == nil
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
