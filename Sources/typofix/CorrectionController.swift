import AppKit

@MainActor
final class CorrectionController {
    private let provider: any LLMProvider
    private let feedback: StatusFeedback
    private let operationGate: OperationGate

    init(provider: any LLMProvider, feedback: StatusFeedback, operationGate: OperationGate) {
        self.provider = provider
        self.feedback = feedback
        self.operationGate = operationGate
    }

    func trigger() {
        guard operationGate.begin() else { return }
        feedback.showInFlight()

        Task {
            defer {
                operationGate.end()
            }

            do {
                try await runCorrection()
                feedback.showSuccess()
            } catch {
                feedback.showWarning()
            }
        }
    }

    private func runCorrection() async throws {
        guard let captured = try await FocusedTextIO.captureCurrentFieldText() else {
            return
        }

        do {
            let corrected = try await provider.correct(captured.text)
            guard corrected != captured.text else {
                FocusedTextIO.restorePasteboard(captured.pasteboardSnapshot)
                return
            }

            await FocusedTextIO.paste(
                corrected,
                restoring: captured.pasteboardSnapshot,
                previousApplication: captured.previousApplication
            )
        } catch {
            FocusedTextIO.restorePasteboard(captured.pasteboardSnapshot)
            throw error
        }
    }
}
