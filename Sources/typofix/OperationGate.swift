import Foundation

@MainActor
final class OperationGate {
    private var isInFlight = false

    func begin() -> Bool {
        guard !isInFlight else { return false }
        isInFlight = true
        return true
    }

    func end() {
        isInFlight = false
    }
}
