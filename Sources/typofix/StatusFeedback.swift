import Observation

@MainActor
@Observable
final class MenuBarState {
    var title = "Tx"
    var launchAtLoginErrorMessage: String?
}

@MainActor
final class StatusFeedback {
    private let state: MenuBarState
    private let normalTitle: String
    private var restoreTask: Task<Void, Never>?

    init(state: MenuBarState, normalTitle: String) {
        self.state = state
        self.normalTitle = normalTitle
    }

    func showNormal() {
        restoreTask?.cancel()
        state.title = normalTitle
    }

    func showInFlight() {
        restoreTask?.cancel()
        state.title = "..."
    }

    func showWarning() {
        showTemporary("⚠︎")
    }

    func showSuccess() {
        showTemporary("✓")
    }

    private func showTemporary(_ title: String) {
        restoreTask?.cancel()
        state.title = title
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.state.title = self?.normalTitle ?? ""
            }
        }
    }
}
