import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let viewModel: SettingsViewModel

    var launchAtLoginDidChange: (() -> Void)? {
        get { viewModel.launchAtLoginDidChange }
        set { viewModel.launchAtLoginDidChange = newValue }
    }

    var shortcutsDidChange: (() -> Void)? {
        get { viewModel.shortcutsDidChange }
        set { viewModel.shortcutsDidChange = newValue }
    }

    init(configStore: ConfigStore) {
        let viewModel = SettingsViewModel(configStore: configStore)
        self.viewModel = viewModel

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typofix Settings"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 620, height: 420)
        window.titlebarSeparatorStyle = .none
        window.center()

        super.init(window: window)

        window.contentViewController = NSHostingController(rootView: SettingsRootView(viewModel: viewModel))
        hideWindowToolbar()
        viewModel.load()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        viewModel.load()
        showWindow(nil)
        hideWindowToolbar()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideWindowToolbar() {
        window?.toolbar?.isVisible = false
        window?.titlebarSeparatorStyle = .none
    }
}
