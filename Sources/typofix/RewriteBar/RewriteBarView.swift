import AppKit

@MainActor
protocol RewriteBarViewDelegate: AnyObject {
    func rewriteBarViewDidRequestClose(_ view: RewriteBarView)
    func rewriteBarViewDidRequestConfirm(_ view: RewriteBarView)
    func rewriteBarView(_ view: RewriteBarView, didSelect variantID: RewriteVariantID)
    func rewriteBarView(_ view: RewriteBarView, didSubmitInstruction instruction: String)
}

final class RewriteBarView: NSGlassEffectView {
    static let fixedWidth: CGFloat = 560

    weak var actionDelegate: RewriteBarViewDelegate?

    private let outerStack = NSStackView()
    private let capturedLabelWrap = NSView()
    private let capturedLabel = NSTextField(labelWithString: "")
    private let separator = NSBox()
    private let scrollView = NSScrollView()
    private let rowsDocumentView = NSView()
    private let rowsStack = NSStackView()
    private let loadingSpinner = NSProgressIndicator()
    private let instructionBackground = NSView()
    private let instructionField = NSTextField()
    private var rowsHeightConstraint: NSLayoutConstraint?
    private var slotViews: [RewriteVariantID: RewriteSlotView] = [:]
    private var isShowingLoadingSpinner = false

    var instructionEditor: AnyObject? {
        instructionField.currentEditor()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(capturedText: String, variants: [RewriteVariant], selectedID: RewriteVariantID?) {
        capturedLabel.stringValue = capturedText

        let loading = variants.count == 1 && variants[0].id == .loading && variants[0].isLoading
        isShowingLoadingSpinner = loading
        loadingSpinner.isHidden = !loading
        rowsStack.isHidden = loading

        for view in slotViews.values {
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        slotViews.removeAll()

        guard !loading else {
            loadingSpinner.startAnimation(nil)
            return
        }

        loadingSpinner.stopAnimation(nil)

        for variant in variants {
            let slot = RewriteSlotView(variantID: variant.id)
            slot.delegate = self
            slot.update(with: variant)
            slot.isSelected = variant.id == selectedID
            rowsStack.addArrangedSubview(slot)
            slot.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            slotViews[variant.id] = slot
        }
    }

    func setRowsHeightLimit(_ maxHeight: CGFloat) {
        layoutSubtreeIfNeeded()

        let contentHeight: CGFloat
        if isShowingLoadingSpinner {
            contentHeight = 56
        } else {
            rowsStack.layoutSubtreeIfNeeded()
            contentHeight = max(1, rowsStack.fittingSize.height)
        }

        rowsHeightConstraint?.constant = min(max(contentHeight, 56), maxHeight)
        scrollView.hasVerticalScroller = false
        scrollView.verticalScrollElasticity = contentHeight > maxHeight ? .allowed : .none
    }

    override func layout() {
        super.layout()
        capturedLabel.preferredMaxLayoutWidth = max(0, capturedLabel.bounds.width)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            actionDelegate?.rewriteBarViewDidRequestClose(self)
        case 36:
            if window?.firstResponder === instructionField.currentEditor() {
                submitInstruction()
            } else {
                actionDelegate?.rewriteBarViewDidRequestConfirm(self)
            }
        case 125:
            selectRelative(offset: 1)
        case 126:
            selectRelative(offset: -1)
        case 18:
            actionDelegate?.rewriteBarView(self, didSelect: .concise)
        case 19:
            actionDelegate?.rewriteBarView(self, didSelect: .polished)
        case 20:
            actionDelegate?.rewriteBarView(self, didSelect: .shorter)
        case 21:
            actionDelegate?.rewriteBarView(self, didSelect: .friendlier)
        case 23:
            actionDelegate?.rewriteBarView(self, didSelect: .formal)
        default:
            super.keyDown(with: event)
        }
    }

    private func setup() {
        style = .regular
        cornerRadius = 30
        tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.22)
        wantsLayer = true
        layer?.cornerRadius = 30
        layer?.masksToBounds = true

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        contentView = content

        // Belt-and-braces: pin the content subtree to the fixed panel width so no
        // descendant's intrinsic content size can ever ask the window to grow.
        content.widthAnchor.constraint(equalToConstant: Self.fixedWidth).isActive = true

        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.distribution = .fill
        outerStack.spacing = 8
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        capturedLabelWrap.translatesAutoresizingMaskIntoConstraints = false

        capturedLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        capturedLabel.textColor = .labelColor
        capturedLabel.lineBreakMode = .byTruncatingTail
        capturedLabel.maximumNumberOfLines = 3
        capturedLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        capturedLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        capturedLabel.translatesAutoresizingMaskIntoConstraints = false

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        rowsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = rowsDocumentView

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.distribution = .fill
        rowsStack.spacing = 2
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .regular
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false

        instructionBackground.wantsLayer = true
        instructionBackground.layer?.cornerRadius = 10
        instructionBackground.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        instructionBackground.layer?.borderWidth = 0
        instructionBackground.translatesAutoresizingMaskIntoConstraints = false

        instructionField.placeholderString = "Eigene Anweisung…"
        instructionField.font = .systemFont(ofSize: 15)
        instructionField.isBordered = false
        instructionField.isBezeled = false
        instructionField.drawsBackground = false
        instructionField.focusRingType = .none
        instructionField.target = self
        instructionField.action = #selector(instructionSubmitted)
        instructionField.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(outerStack)
        rowsDocumentView.addSubview(rowsStack)
        rowsDocumentView.addSubview(loadingSpinner)
        instructionBackground.addSubview(instructionField)
        capturedLabelWrap.addSubview(capturedLabel)

        outerStack.addArrangedSubview(capturedLabelWrap)
        outerStack.addArrangedSubview(separator)
        outerStack.addArrangedSubview(scrollView)
        outerStack.addArrangedSubview(instructionBackground)

        let rowsHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 56)
        self.rowsHeightConstraint = rowsHeightConstraint

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            outerStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            outerStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            outerStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),

            capturedLabelWrap.widthAnchor.constraint(equalTo: outerStack.widthAnchor),
            capturedLabel.topAnchor.constraint(equalTo: capturedLabelWrap.topAnchor),
            capturedLabel.bottomAnchor.constraint(equalTo: capturedLabelWrap.bottomAnchor),
            capturedLabel.leadingAnchor.constraint(equalTo: capturedLabelWrap.leadingAnchor, constant: 14),
            capturedLabel.trailingAnchor.constraint(equalTo: capturedLabelWrap.trailingAnchor, constant: -14),

            separator.widthAnchor.constraint(equalTo: outerStack.widthAnchor),

            scrollView.widthAnchor.constraint(equalTo: outerStack.widthAnchor),
            rowsHeightConstraint,

            rowsDocumentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            rowsDocumentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            rowsStack.topAnchor.constraint(equalTo: rowsDocumentView.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: rowsDocumentView.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: rowsDocumentView.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: rowsDocumentView.bottomAnchor),
            rowsStack.widthAnchor.constraint(equalTo: rowsDocumentView.widthAnchor),

            loadingSpinner.centerXAnchor.constraint(equalTo: rowsDocumentView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: rowsDocumentView.centerYAnchor),
            loadingSpinner.widthAnchor.constraint(equalToConstant: 28),
            loadingSpinner.heightAnchor.constraint(equalToConstant: 28),

            instructionBackground.widthAnchor.constraint(equalTo: outerStack.widthAnchor),
            instructionBackground.heightAnchor.constraint(equalToConstant: 38),

            instructionField.centerYAnchor.constraint(equalTo: instructionBackground.centerYAnchor),
            instructionField.leadingAnchor.constraint(equalTo: instructionBackground.leadingAnchor, constant: 14),
            instructionField.trailingAnchor.constraint(equalTo: instructionBackground.trailingAnchor, constant: -14)
        ])
    }

    private func selectRelative(offset: Int) {
        let orderedIDs = rowsStack.arrangedSubviews.compactMap { ($0 as? RewriteSlotView)?.variantID }
        guard let selectedIndex = orderedIDs.firstIndex(where: { slotViews[$0]?.isSelected == true }) else {
            if let first = orderedIDs.first {
                actionDelegate?.rewriteBarView(self, didSelect: first)
            }
            return
        }

        let nextIndex = min(max(selectedIndex + offset, 0), orderedIDs.count - 1)
        actionDelegate?.rewriteBarView(self, didSelect: orderedIDs[nextIndex])
    }

    @objc private func instructionSubmitted() {
        submitInstruction()
    }

    private func submitInstruction() {
        let instruction = instructionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        actionDelegate?.rewriteBarView(self, didSubmitInstruction: instruction)
    }
}

extension RewriteBarView: RewriteSlotViewDelegate {
    func rewriteSlotViewDidSelect(_ view: RewriteSlotView) {
        actionDelegate?.rewriteBarView(self, didSelect: view.variantID)
        window?.makeKey()
    }

    func rewriteSlotViewDidConfirm(_ view: RewriteSlotView) {
        actionDelegate?.rewriteBarView(self, didSelect: view.variantID)
        actionDelegate?.rewriteBarViewDidRequestConfirm(self)
    }
}
