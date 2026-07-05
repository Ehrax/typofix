import AppKit

@MainActor
final class StatusFeedback {
    private let item: NSStatusItem
    private let normalTitle: String
    private var restoreTask: Task<Void, Never>?

    init(item: NSStatusItem, normalTitle: String) {
        self.item = item
        self.normalTitle = normalTitle
    }

    func showNormal() {
        restoreTask?.cancel()
        item.button?.title = normalTitle
    }

    func showInFlight() {
        restoreTask?.cancel()
        item.button?.title = "..."
    }

    func showWarning() {
        showTemporary("⚠︎")
    }

    func showSuccess() {
        showTemporary("✓")
    }

    private func showTemporary(_ title: String) {
        restoreTask?.cancel()
        item.button?.title = title
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.item.button?.title = self?.normalTitle ?? ""
            }
        }
    }
}
