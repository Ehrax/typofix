import AppKit
import SwiftUI

@main
struct TypofixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            TypofixMenuBarContent(appDelegate: appDelegate)
        } label: {
            Text(appDelegate.menuBarState.title)
        }

        Settings {
            SettingsSceneView(
                configStore: appDelegate.configStore,
                onLaunchAtLoginDidChange: appDelegate.settingsLaunchAtLoginDidChange,
                onShortcutsDidChange: appDelegate.settingsShortcutsDidChange
            )
        }
        .defaultSize(width: 760, height: 520)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text("Settings...")
                }
            }
        }
    }
}

private struct TypofixMenuBarContent: View {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Fix current input") {
            appDelegate.fixCurrentInputFromMenu()
        }

        Button("Settings...") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Open config") {
            appDelegate.openConfigFromMenu()
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { appDelegate.setLaunchAtLoginFromMenu($0) }
        ))
        .disabled(!LaunchAtLogin.isAvailable)
        .help(LaunchAtLogin.isAvailable ? "" : LaunchAtLogin.unavailableTooltip)

        if let errorMessage = appDelegate.menuBarState.launchAtLoginErrorMessage {
            Text(errorMessage)
        }

        Divider()

        Button(AccessibilityPermission.isTrusted ? "Accessibility: allowed" : "Accessibility: required for typing") {
            appDelegate.refreshAccessibilityStatusFromMenu()
        }
        .disabled(AccessibilityPermission.isTrusted)

        Divider()

        Button("Quit") {
            appDelegate.quitFromMenu()
        }
        .keyboardShortcut("q")
    }
}
