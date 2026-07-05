import AppKit

@MainActor
protocol RewriteSlotViewDelegate: AnyObject {
    func rewriteSlotViewDidSelect(_ view: RewriteSlotView)
    func rewriteSlotViewDidConfirm(_ view: RewriteSlotView)
}

final class RewriteSlotView: NSView {
    weak var delegate: RewriteSlotViewDelegate?
    let variantID: RewriteVariantID

    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "")

    var isSelected = false {
        didSet { updateSelectionStyle() }
    }

    init(variantID: RewriteVariantID) {
        self.variantID = variantID
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with variant: RewriteVariant) {
        titleLabel.stringValue = variant.title.uppercased()
        setBodyText(
            variant.errorText ?? variant.result ?? "",
            color: variant.errorText == nil ? .labelColor : .systemRed
        )
    }

    override func layout() {
        super.layout()
        bodyLabel.preferredMaxLayoutWidth = max(0, bounds.width - 28)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.rewriteSlotViewDidSelect(self)
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 2 {
            delegate?.rewriteSlotViewDidConfirm(self)
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.font = .systemFont(ofSize: 15)
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 4
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        updateSelectionStyle()
    }

    private func updateSelectionStyle() {
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.28).cgColor
            : NSColor.clear.cgColor
    }

    private func setBodyText(_ text: String, color: NSColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 1.5

        bodyLabel.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}
