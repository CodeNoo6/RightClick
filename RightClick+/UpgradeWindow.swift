import Cocoa

class UpgradeWindowController: NSWindowController {
    static let shared = UpgradeWindowController()

    private init() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.center()
        w.setFrameAutosaveName("Upgrade")
        super.init(window: w)
        w.contentView = UpgradeView()
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Refresh view state each time it opens
        (window?.contentView as? UpgradeView)?.reset()
        showWindow(nil)
        window?.center()
    }
}

class UpgradeView: NSView {

    private var keyField: NSTextField!
    private var statusLabel: NSTextField!
    private var activateBtn: NSButton!

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    private func loc(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    func reset() {
        keyField?.stringValue = ""
        statusLabel?.stringValue = ""
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Lock icon
        let icon = NSTextField(labelWithString: "🔒")
        icon.font = .systemFont(ofSize: 36)
        icon.alignment = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        // Title
        let title = NSTextField(labelWithString: loc("upgrade.title"))
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        // Subtitle
        let sub = NSTextField(labelWithString: loc("upgrade.subtitle"))
        sub.font = .systemFont(ofSize: 12)
        sub.textColor = .secondaryLabelColor
        sub.alignment = .center
        sub.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sub)

        // Separator
        let sep1 = NSBox(); sep1.boxType = .separator
        sep1.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep1)

        // Features
        let featStack = NSStackView()
        featStack.orientation = .vertical
        featStack.alignment = .leading
        featStack.spacing = 6
        featStack.translatesAutoresizingMaskIntoConstraints = false
        for key in ["upgrade.feat1", "upgrade.feat2", "upgrade.feat3"] {
            let lbl = NSTextField(labelWithString: loc(key))
            lbl.font = .systemFont(ofSize: 12.5)
            lbl.textColor = .labelColor
            featStack.addArrangedSubview(lbl)
        }
        addSubview(featStack)

        // Pricing pills
        let priceStack = NSStackView()
        priceStack.orientation = .horizontal
        priceStack.spacing = 6
        priceStack.translatesAutoresizingMaskIntoConstraints = false
        for key in ["upgrade.monthly", "upgrade.annual"] {
            let pill = NSTextField(labelWithString: loc(key))
            pill.font = .systemFont(ofSize: 10.5, weight: .medium)
            pill.textColor = .secondaryLabelColor
            pill.wantsLayer = true
            pill.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            pill.layer?.cornerRadius = 5
            pill.isBordered = false
            pill.isEditable = false
            pill.setContentHuggingPriority(.required, for: .horizontal)
            priceStack.addArrangedSubview(pill)
        }
        addSubview(priceStack)

        // Buy button
        let buyBtn = NSButton()
        buyBtn.title = loc("upgrade.buy")
        buyBtn.bezelStyle = .rounded
        buyBtn.font = .systemFont(ofSize: 13, weight: .semibold)
        buyBtn.contentTintColor = .white
        buyBtn.wantsLayer = true
        buyBtn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        buyBtn.layer?.cornerRadius = 8
        buyBtn.isBordered = false
        buyBtn.target = self
        buyBtn.action = #selector(buyTapped)
        buyBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buyBtn)

        // Separator 2
        let sep2 = NSBox(); sep2.boxType = .separator
        sep2.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep2)

        // Key field
        keyField = NSTextField()
        keyField.placeholderString = loc("upgrade.key_placeholder")
        keyField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        keyField.bezelStyle = .roundedBezel
        keyField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keyField)

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        // Buttons row
        let cancelBtn = NSButton()
        cancelBtn.title = loc("upgrade.cancel")
        cancelBtn.bezelStyle = .inline
        cancelBtn.isBordered = false
        cancelBtn.font = .systemFont(ofSize: 12)
        cancelBtn.contentTintColor = .secondaryLabelColor
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelTapped)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cancelBtn)

        activateBtn = NSButton()
        activateBtn.title = loc("upgrade.activate")
        activateBtn.bezelStyle = .rounded
        activateBtn.font = .systemFont(ofSize: 12, weight: .medium)
        activateBtn.translatesAutoresizingMaskIntoConstraints = false
        activateBtn.target = self
        activateBtn.action = #selector(activateTapped)
        addSubview(activateBtn)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 36),

            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),

            sub.centerXAnchor.constraint(equalTo: centerXAnchor),
            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),

            sep1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            sep1.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            sep1.topAnchor.constraint(equalTo: sub.bottomAnchor, constant: 16),

            featStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            featStack.topAnchor.constraint(equalTo: sep1.bottomAnchor, constant: 14),

            priceStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            priceStack.topAnchor.constraint(equalTo: featStack.bottomAnchor, constant: 14),

            buyBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            buyBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            buyBtn.topAnchor.constraint(equalTo: priceStack.bottomAnchor, constant: 12),
            buyBtn.heightAnchor.constraint(equalToConstant: 36),

            sep2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            sep2.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            sep2.topAnchor.constraint(equalTo: buyBtn.bottomAnchor, constant: 16),

            keyField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            keyField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            keyField.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 14),

            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: keyField.bottomAnchor, constant: 6),

            cancelBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            cancelBtn.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),

            activateBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            activateBtn.centerYAnchor.constraint(equalTo: cancelBtn.centerYAnchor),
        ])
    }

    @objc private func buyTapped() {
        // TODO: replace with Bold checkout URL
        NSWorkspace.shared.open(URL(string: "https://rightclickmac.com/#pricing")!)
    }

    @objc private func activateTapped() {
        let key = keyField.stringValue.uppercased()
        activateBtn.isEnabled = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Validating…"

        LicenseManager.shared.activate(key: key) { [weak self] success, message in
            self?.activateBtn.isEnabled = true
            self?.statusLabel.stringValue = message
            self?.statusLabel.textColor = success ? .systemGreen : .systemRed
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self?.window?.close()
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    @objc private func cancelTapped() {
        window?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}
