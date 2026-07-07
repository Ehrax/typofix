import AppKit

private struct SmartProviderContext: Sendable {
    let provider: any LLMProvider
    let providerID: String
    let modelID: String
}

@MainActor
final class RewriteBarController {
    private let configStore: ConfigStore
    private let operationGate: OperationGate
    private var captured: CapturedFocusedText?
    private var panel: RewritePanel?
    private var barView: RewriteBarView?
    private var variants: [RewriteVariant] = []
    private var selectedID: RewriteVariantID = .concise
    private var variantTasks: [RewriteVariantID: Task<Void, Never>] = [:]
    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var moveObserver: NSObjectProtocol?
    private var pendingSelectionOffset = 0
    private var pendingSelectionIndex: Int?
    private var isProgrammaticResize = false
    private var isClosing = false

    init(configStore: ConfigStore, operationGate: OperationGate) {
        self.configStore = configStore
        self.operationGate = operationGate
    }

    func trigger() {
        guard operationGate.begin() else { return }

        Task {
            do {
                guard let captured = try await FocusedTextIO.captureCurrentFieldText() else {
                    operationGate.end()
                    return
                }
                show(captured: captured)
            } catch {
                operationGate.end()
            }
        }
    }

    private func show(captured: CapturedFocusedText) {
        self.captured = captured
        variants = [
            RewriteVariant(id: .loading, title: "Varianten", result: nil, isLoading: true, errorText: nil)
        ]
        selectedID = .loading
        pendingSelectionOffset = 0
        pendingSelectionIndex = nil

        let panelFrame = initialPanelFrame(width: Self.panelWidth, height: 260)
        let panel = RewritePanel(contentRect: panelFrame)
        panel.minSize = NSSize(width: Self.panelWidth, height: 0)
        panel.maxSize = NSSize(width: Self.panelWidth, height: CGFloat.greatestFiniteMagnitude)
        let barView = RewriteBarView(frame: NSRect(origin: .zero, size: panelFrame.size))
        barView.actionDelegate = self
        panel.closeDelegate = self
        panel.contentView = barView

        self.panel = panel
        self.barView = barView
        installMouseMonitor()
        installKeyMonitor()
        installMoveObserver()
        render()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(barView)

        switch makeSmartProvider() {
        case .success(let context):
            requestInitialVariants(context: context)
        case .failure(let error):
            setVariant(.loading, loading: false, result: nil, errorText: Self.shortErrorText(for: error))
        }
    }

    private func requestInitialVariants(context: SmartProviderContext) {
        guard let captured else { return }

        variantTasks[.loading]?.cancel()
        variantTasks[.loading] = Task { [capturedText = captured.text] in
            do {
                let instruction = PromptCatalog.rewriteVariantsPrompt(
                    providerID: context.providerID,
                    modelID: context.modelID
                )
                let results = try await context.provider.rewriteVariants(capturedText, instruction: instruction)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.variants = zip(Self.initialVariantDefinitions, results).map { definition, result in
                        RewriteVariant(
                            id: definition.id,
                            title: definition.title,
                            result: result,
                            isLoading: false,
                            errorText: nil
                        )
                    }
                    let selectedIndex = self.pendingSelectionIndex
                        ?? min(max(self.pendingSelectionOffset, 0), Self.initialVariantDefinitions.count - 1)
                    self.selectedID = Self.initialVariantDefinitions[selectedIndex].id
                    self.pendingSelectionOffset = 0
                    self.pendingSelectionIndex = nil
                    self.render()
                }
            } catch {
                guard !Task.isCancelled else { return }
                let errorText = Self.shortErrorText(for: error)
                await MainActor.run {
                    self.setVariant(.loading, loading: false, result: nil, errorText: errorText)
                }
            }
        }
    }

    private func requestVariant(_ id: RewriteVariantID, provider: any LLMProvider, instruction: String) {
        guard let captured else { return }
        setVariant(id, loading: true, result: nil, errorText: nil)

        variantTasks[id]?.cancel()
        variantTasks[id] = Task { [capturedText = captured.text] in
            do {
                let result = try await provider.rewrite(capturedText, instruction: instruction, temperature: nil)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.setVariant(id, loading: false, result: result, errorText: nil)
                }
            } catch {
                guard !Task.isCancelled else { return }
                let errorText = Self.shortErrorText(for: error)
                await MainActor.run {
                    self.setVariant(id, loading: false, result: nil, errorText: errorText)
                }
            }
        }
    }

    private func requestInstructionVariant(_ instruction: String) {
        switch makeSmartProvider() {
        case .success(let context):
            replaceWithInstructionVariant()
            selectedID = .instruction
            let prompt = PromptCatalog.rewriteInstructionPrompt(
                providerID: context.providerID,
                modelID: context.modelID,
                userInstruction: instruction
            )
            requestVariant(.instruction, provider: context.provider, instruction: prompt)
        case .failure(let error):
            replaceWithInstructionVariant()
            selectedID = .instruction
            setVariant(.instruction, loading: false, result: nil, errorText: Self.shortErrorText(for: error))
        }
    }

    private func makeSmartProvider() -> Result<SmartProviderContext, Error> {
        Result {
            let config = try configStore.loadOrCreate()
            return SmartProviderContext(
                provider: try ProviderFactory.makeSmartProvider(config: config),
                providerID: config.smartProvider,
                modelID: config.smartModel
            )
        }
    }

    private func replaceWithInstructionVariant() {
        variants = [
            RewriteVariant(id: .instruction, title: "Eigene Anweisung", result: nil, isLoading: true, errorText: nil)
        ]
        render()
    }

    private func setVariant(
        _ id: RewriteVariantID,
        loading: Bool,
        result: String?,
        errorText: String?
    ) {
        guard let index = variants.firstIndex(where: { $0.id == id }) else { return }
        variants[index].isLoading = loading
        variants[index].result = result
        variants[index].errorText = errorText
        render()
    }

    private func confirmSelection() {
        guard
            let captured,
            let variant = variants.first(where: { $0.id == selectedID }),
            let result = variant.result,
            !variant.isLoading
        else {
            return
        }

        closePanel(restorePasteboard: false, endOperation: false)

        Task {
            await FocusedTextIO.paste(
                result,
                restoring: captured.pasteboardSnapshot,
                previousApplication: captured.previousApplication
            )
            operationGate.end()
            self.captured = nil
        }
    }

    private func closePanel(restorePasteboard: Bool, endOperation: Bool = true) {
        guard !isClosing else { return }
        isClosing = true

        for task in variantTasks.values {
            task.cancel()
        }
        variantTasks.removeAll()

        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
            self.moveObserver = nil
        }

        if restorePasteboard, let captured {
            FocusedTextIO.restorePasteboard(captured.pasteboardSnapshot)
        }

        if restorePasteboard {
            captured?.previousApplication?.activate()
        }

        panel?.closeDelegate = nil
        panel?.orderOut(nil)
        panel = nil
        barView = nil

        if endOperation {
            operationGate.end()
            captured = nil
        }

        isClosing = false
    }

    private func render() {
        barView?.configure(capturedText: captured?.text ?? "", variants: variants, selectedID: selectedID)
        resizePanelToFitContent()
    }

    private func centeredPanelFrame(width: CGFloat, height: CGFloat) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - screenFrame.height * 0.30 - height / 2
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private func initialPanelFrame(width: CGFloat, height: CGFloat) -> NSRect {
        let centered = centeredPanelFrame(width: width, height: height)
        guard let saved = UserDefaults.standard.string(forKey: Self.originDefaultsKey) else {
            return centered
        }

        let origin = NSPointFromString(saved)
        let frame = NSRect(origin: origin, size: NSSize(width: width, height: height))
        guard let screen = screen(for: frame) else {
            return centered
        }

        return clamped(frame, to: screen.visibleFrame)
    }

    private func resizePanelToFitContent() {
        guard let panel, let barView else { return }

        barView.layoutSubtreeIfNeeded()
        let currentVisibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let maxPanelHeight = currentVisibleFrame.height * 0.70
        barView.setRowsHeightLimit(maxPanelHeight)
        barView.layoutSubtreeIfNeeded()

        var fittingHeight = barView.fittingSize.height
        if fittingHeight > maxPanelHeight {
            let overflow = fittingHeight - maxPanelHeight
            barView.setRowsHeightLimit(max(56, maxPanelHeight - overflow))
            barView.layoutSubtreeIfNeeded()
            fittingHeight = barView.fittingSize.height
        }

        let targetHeight = min(max(fittingHeight, 190), maxPanelHeight)
        let topEdge = panel.frame.maxY
        let unclampedFrame = NSRect(
            x: panel.frame.origin.x,
            y: topEdge - targetHeight,
            width: Self.panelWidth,
            height: targetHeight
        )
        let targetVisibleFrame = panel.screen?.visibleFrame ?? screen(for: unclampedFrame)?.visibleFrame ?? currentVisibleFrame
        let targetFrame = clamped(unclampedFrame, to: targetVisibleFrame)
        isProgrammaticResize = true
        panel.setFrame(targetFrame, display: true, animate: false)
        isProgrammaticResize = false
    }

    private func screen(for frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
            ?? NSScreen.screens.first { $0.visibleFrame.contains(frame.origin) }
            ?? NSScreen.main
    }

    private func clamped(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        var clamped = frame
        clamped.size.width = Self.panelWidth
        clamped.origin.x = min(
            max(clamped.origin.x, visibleFrame.minX),
            visibleFrame.maxX - clamped.width
        )
        clamped.origin.y = min(
            max(clamped.origin.y, visibleFrame.minY),
            visibleFrame.maxY - clamped.height
        )
        return clamped
    }

    private func installMouseMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, let panel = self.panel else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self.closePanel(restorePasteboard: true)
                }
            }
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isInstructionEditing = event.window?.firstResponder === self.barView?.instructionEditor

            if flags == .control {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "j":
                    self.selectRelative(offset: 1)
                    return nil
                case "k":
                    self.selectRelative(offset: -1)
                    return nil
                default:
                    return event
                }
            }

            guard !isInstructionEditing else {
                return event
            }

            switch event.keyCode {
            case 125:
                self.selectRelative(offset: 1)
                return nil
            case 126:
                self.selectRelative(offset: -1)
                return nil
            case 18, 19, 20, 21, 23:
                self.selectNumberedVariant(for: event.keyCode)
                return nil
            case 36:
                self.confirmSelection()
                return nil
            case 53:
                self.closePanel(restorePasteboard: true)
                return nil
            default:
                return event
            }
        }
    }

    private func installMoveObserver() {
        guard let panel else { return }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            MainActor.assumeIsolated {
                guard
                    let self,
                    let panel,
                    !self.isProgrammaticResize,
                    panel === self.panel
                else {
                    return
                }

                UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originDefaultsKey)
            }
        }
    }

    private func selectRelative(offset: Int) {
        let selectableVariants = variants.filter { !$0.isLoading && $0.result != nil }
        guard let selectedIndex = selectableVariants.firstIndex(where: { $0.id == selectedID }) else {
            if let first = selectableVariants.first {
                selectedID = first.id
                render()
            } else {
                pendingSelectionOffset += offset
            }
            return
        }

        let nextIndex = min(max(selectedIndex + offset, 0), selectableVariants.count - 1)
        selectedID = selectableVariants[nextIndex].id
        render()
    }

    private func selectNumberedVariant(for keyCode: UInt16) {
        let index: Int
        switch keyCode {
        case 18: index = 0
        case 19: index = 1
        case 20: index = 2
        case 21: index = 3
        case 23: index = 4
        default: return
        }

        let selectableVariants = variants.filter { !$0.isLoading && $0.result != nil }
        guard selectableVariants.indices.contains(index) else {
            pendingSelectionIndex = index
            return
        }
        selectedID = selectableVariants[index].id
        render()
    }

    private static let initialVariantDefinitions: [(id: RewriteVariantID, title: String)] = [
        (.concise, "Auf den Punkt"),
        (.polished, "Polished"),
        (.shorter, "Kürzer"),
        (.friendlier, "Freundlicher"),
        (.formal, "Formeller")
    ]

    private static let panelWidth: CGFloat = RewriteBarView.fixedWidth
    private static let originDefaultsKey = "RewriteBarOrigin"

    static let variantsPrompt = """
    \(PromptCatalog.defaultRewriteVariantsPrompt)
    """

    private static func instructionPrompt(userInstruction: String) -> String {
        PromptCatalog.rewriteInstructionPrompt(providerID: "", modelID: "", userInstruction: userInstruction)
    }

    private static func shortErrorText(for error: Error) -> String {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let collapsed = message
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 140 else { return collapsed }
        return String(collapsed.prefix(137)) + "..."
    }
}

extension RewriteBarController: RewriteBarViewDelegate {
    func rewriteBarViewDidRequestClose(_ view: RewriteBarView) {
        closePanel(restorePasteboard: true)
    }

    func rewriteBarViewDidRequestConfirm(_ view: RewriteBarView) {
        confirmSelection()
    }

    func rewriteBarView(_ view: RewriteBarView, didSelect variantID: RewriteVariantID) {
        guard variants.contains(where: { $0.id == variantID }) else { return }
        selectedID = variantID
        render()
    }

    func rewriteBarView(_ view: RewriteBarView, didSubmitInstruction instruction: String) {
        requestInstructionVariant(instruction)
    }
}

extension RewriteBarController: RewritePanelDelegate {
    func rewritePanelDidRequestClose(_ panel: RewritePanel) {
        closePanel(restorePasteboard: true)
    }
}
