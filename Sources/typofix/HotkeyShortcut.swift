import AppKit

enum HotkeyShortcut: String, CaseIterable, Codable, Sendable {
    case disabled
    case doubleControl
    case doubleOption
    case doubleShift
    case doubleCommand

    static let defaultFast: HotkeyShortcut = .doubleShift
    static let defaultRewrite: HotkeyShortcut = .doubleOption

    var displayName: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .doubleControl:
            return "Double Control"
        case .doubleOption:
            return "Double Option"
        case .doubleShift:
            return "Double Shift"
        case .doubleCommand:
            return "Double Command"
        }
    }

    var modifier: NSEvent.ModifierFlags? {
        switch self {
        case .disabled:
            return nil
        case .doubleControl:
            return .control
        case .doubleOption:
            return .option
        case .doubleShift:
            return .shift
        case .doubleCommand:
            return .command
        }
    }
}
