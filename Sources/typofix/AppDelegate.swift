import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configStore = ConfigStore()
    private var statusItem: NSStatusItem?
    private var feedback: StatusFeedback?
    private var correctionController: CorrectionController?
    private var rewriteBarController: RewriteBarController?
    private var commandHotkeyMonitor: HotkeyMonitor?
    private var optionHotkeyMonitor: HotkeyMonitor?
    private var accessibilityItem: NSMenuItem?
    private let operationGate = OperationGate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        _ = AccessibilityPermission.requestIfNeeded()
        updateAccessibilityMenuItem()

        do {
            let config = try configStore.loadOrCreate()
            let fastProvider = try ProviderFactory.makeFastProvider(config: config)
            let smartProvider = Result { try ProviderFactory.makeSmartProvider(config: config) }
            guard let feedback else { return }
            correctionController = CorrectionController(
                provider: fastProvider,
                feedback: feedback,
                operationGate: operationGate
            )
            rewriteBarController = RewriteBarController(
                smartProvider: smartProvider,
                operationGate: operationGate
            )
            commandHotkeyMonitor = HotkeyMonitor(modifier: .command) { [weak self] in
                self?.correctionController?.trigger()
            }
            optionHotkeyMonitor = HotkeyMonitor(modifier: .option) { [weak self] in
                self?.rewriteBarController?.trigger()
            }
            commandHotkeyMonitor?.start()
            optionHotkeyMonitor?.start()
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func refreshAccessibilityStatus() {
        updateAccessibilityMenuItem()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Tx"
        item.button?.toolTip = "Typofix"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Fix current input", action: #selector(fixCurrentInput), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open config", action: #selector(openConfig), keyEquivalent: ""))
        menu.addItem(.separator())

        let accessibility = NSMenuItem(title: "", action: #selector(refreshAccessibilityStatus), keyEquivalent: "")
        menu.addItem(accessibility)
        accessibilityItem = accessibility

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
        feedback = StatusFeedback(item: item, normalTitle: "Tx")
    }

    private func updateAccessibilityMenuItem() {
        let trusted = AccessibilityPermission.isTrusted
        accessibilityItem?.title = trusted
            ? "Accessibility: allowed"
            : "Accessibility: required for typing"
        accessibilityItem?.isEnabled = !trusted
    }
}
