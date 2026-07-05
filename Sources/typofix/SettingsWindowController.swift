import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let configStore: ConfigStore

    private let fastModelField = NSTextField()
    private let fastKeySecureField = NSSecureTextField()
    private let fastKeyTextField = NSTextField()
    private let fastShowButton = NSButton(checkboxWithTitle: "Show", target: nil, action: nil)

    private let smartModelField = NSTextField()
    private let smartKeySecureField = NSSecureTextField()
    private let smartKeyTextField = NSTextField()
    private let smartShowButton = NSButton(checkboxWithTitle: "Show", target: nil, action: nil)

    private var config = TypofixConfig.defaults
    private var isLoading = false

    init(configStore: ConfigStore) {
        self.configStore = configStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 258),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typofix Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.contentView = makeContentView()
        loadConfig()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        loadConfig()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !isLoading else { return }
        syncKeyFields(from: obj.object as? NSTextField)
        saveConfig()
    }

    @objc private func saveButtonClicked() {
        syncKeyFields(from: nil)
        saveConfig()
    }

    @objc private func showButtonChanged(_ sender: NSButton) {
        switch sender {
        case fastShowButton:
            syncPair(secureField: fastKeySecureField, textField: fastKeyTextField, preferSecure: !fastKeySecureField.isHidden)
            setKeyVisible(sender.state == .on, secureField: fastKeySecureField, textField: fastKeyTextField)
        case smartShowButton:
            syncPair(secureField: smartKeySecureField, textField: smartKeyTextField, preferSecure: !smartKeySecureField.isHidden)
            setKeyVisible(sender.state == .on, secureField: smartKeySecureField, textField: smartKeyTextField)
        default:
            break
        }
    }

    private func makeContentView() -> NSView {
        [fastModelField, fastKeySecureField, fastKeyTextField, smartModelField, smartKeySecureField, smartKeyTextField].forEach {
            $0.delegate = self
            $0.lineBreakMode = .byTruncatingTail
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        fastShowButton.target = self
        fastShowButton.action = #selector(showButtonChanged(_:))
        smartShowButton.target = self
        smartShowButton.action = #selector(showButtonChanged(_:))

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 16, right: 18)

        stack.addArrangedSubview(sectionTitle("Fast fix (Cmd+Cmd)"))
        stack.addArrangedSubview(grid(rows: [
            ("Provider", NSTextField(labelWithString: "Groq")),
            ("Model", fastModelField),
            ("API key", keyFieldStack(secureField: fastKeySecureField, textField: fastKeyTextField, showButton: fastShowButton))
        ]))

        stack.addArrangedSubview(sectionTitle("Rewrite bar (Opt+Opt)"))
        stack.addArrangedSubview(grid(rows: [
            ("Provider", NSTextField(labelWithString: "Anthropic")),
            ("Model", smartModelField),
            ("API key", keyFieldStack(secureField: smartKeySecureField, textField: smartKeyTextField, showButton: smartShowButton))
        ]))

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveButtonClicked))
        saveButton.bezelStyle = .rounded
        let buttonRow = NSStackView(views: [saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.setHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(buttonRow)

        let contentView = NSView()
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        return contentView
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .preferredFont(forTextStyle: .headline)
        return label
    }

    private func grid(rows: [(String, NSView)]) -> NSGridView {
        let grid = NSGridView(views: rows.map { label, value in
            [NSTextField(labelWithString: label), value]
        })
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 72
        grid.column(at: 1).width = 292
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        return grid
    }

    private func keyFieldStack(secureField: NSSecureTextField, textField: NSTextField, showButton: NSButton) -> NSStackView {
        secureField.placeholderString = "Stored in config.json"
        textField.placeholderString = "Stored in config.json"
        textField.isHidden = true

        let fieldStack = NSStackView(views: [secureField, textField])
        fieldStack.orientation = .vertical
        fieldStack.spacing = 0
        fieldStack.setHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [fieldStack, showButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.setHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            secureField.widthAnchor.constraint(equalToConstant: 210),
            textField.widthAnchor.constraint(equalTo: secureField.widthAnchor)
        ])

        return stack
    }

    private func loadConfig() {
        isLoading = true
        defer { isLoading = false }

        do {
            config = try configStore.loadOrCreate()
        } catch {
            config = .defaults
        }

        fastModelField.stringValue = config.model
        fastKeySecureField.stringValue = config.apiKey ?? ""
        fastKeyTextField.stringValue = config.apiKey ?? ""
        smartModelField.stringValue = config.smartModel
        smartKeySecureField.stringValue = config.anthropicApiKey ?? ""
        smartKeyTextField.stringValue = config.anthropicApiKey ?? ""
    }

    private func saveConfig() {
        config.provider = TypofixConfig.defaultProvider
        config.model = fastModelField.stringValue
        config.apiKey = fastKeyValue.nilIfBlank
        config.smartProvider = TypofixConfig.defaultSmartProvider
        config.smartModel = smartModelField.stringValue
        config.anthropicApiKey = smartKeyValue.nilIfBlank

        do {
            try configStore.save(config)
        } catch {
            NSSound.beep()
        }
    }

    private var fastKeyValue: String {
        fastKeySecureField.isHidden ? fastKeyTextField.stringValue : fastKeySecureField.stringValue
    }

    private var smartKeyValue: String {
        smartKeySecureField.isHidden ? smartKeyTextField.stringValue : smartKeySecureField.stringValue
    }

    private func setKeyVisible(_ isVisible: Bool, secureField: NSSecureTextField, textField: NSTextField) {
        secureField.isHidden = isVisible
        textField.isHidden = !isVisible
        window?.recalculateKeyViewLoop()
    }

    private func syncKeyFields(from field: NSTextField?) {
        if field === fastKeySecureField {
            fastKeyTextField.stringValue = fastKeySecureField.stringValue
        } else if field === fastKeyTextField {
            fastKeySecureField.stringValue = fastKeyTextField.stringValue
        } else if field === smartKeySecureField {
            smartKeyTextField.stringValue = smartKeySecureField.stringValue
        } else if field === smartKeyTextField {
            smartKeySecureField.stringValue = smartKeyTextField.stringValue
        }
    }

    private func syncPair(secureField: NSSecureTextField, textField: NSTextField, preferSecure: Bool) {
        if preferSecure {
            textField.stringValue = secureField.stringValue
        } else {
            secureField.stringValue = textField.stringValue
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
