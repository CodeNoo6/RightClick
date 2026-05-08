import Cocoa
import FinderSync

class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()

    private init() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.center()
        w.setFrameAutosaveName("Onboarding")
        super.init(window: w)
        w.contentView = OnboardingView()
    }
    required init?(coder: NSCoder) { fatalError() }
}

class OnboardingView: NSView {
    private var step1Done = false
    private var step2Done = false
    private var step1Card: NSView!
    private var step2Card: NSView!
    private var actionBtn: NSButton!
    private var timer: Timer?

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        let title = label(NSLocalizedString("onboarding.title", comment: ""), size: 22, weight: .bold)
        addSubview(title)

        let sub = label(NSLocalizedString("onboarding.subtitle", comment: ""), size: 13, weight: .regular, muted: true)
        addSubview(sub)

        let div = NSBox(); div.boxType = .separator
        div.translatesAutoresizingMaskIntoConstraints = false
        addSubview(div)

        step1Card = stepView(number: "1",
            title: NSLocalizedString("onboarding.step1.title", comment: ""),
            detail: NSLocalizedString("onboarding.step1.detail", comment: ""),
            highlight: true)

        step2Card = stepView(number: "2",
            title: NSLocalizedString("onboarding.step2.title", comment: ""),
            detail: NSLocalizedString("onboarding.step2.detail", comment: ""),
            highlight: false)

        addSubview(step1Card)
        addSubview(step2Card)

        actionBtn = NSButton()
        actionBtn.title = NSLocalizedString("onboarding.btn.step1", comment: "")
        actionBtn.bezelStyle = .rounded
        actionBtn.font = .systemFont(ofSize: 14, weight: .semibold)
        actionBtn.contentTintColor = .white
        actionBtn.wantsLayer = true
        actionBtn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        actionBtn.layer?.cornerRadius = 8
        actionBtn.isBordered = false
        actionBtn.target = self
        actionBtn.action = #selector(actionTapped)
        actionBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionBtn)

        let skip = NSButton()
        skip.title = NSLocalizedString("onboarding.skip", comment: "")
        skip.bezelStyle = .inline; skip.isBordered = false
        skip.font = .systemFont(ofSize: 12)
        skip.contentTintColor = .secondaryLabelColor
        skip.target = self; skip.action = #selector(skipTapped)
        skip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skip)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 48),
            icon.widthAnchor.constraint(equalToConstant: 80),
            icon.heightAnchor.constraint(equalToConstant: 80),

            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),

            sub.centerXAnchor.constraint(equalTo: centerXAnchor),
            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),

            div.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            div.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            div.topAnchor.constraint(equalTo: sub.bottomAnchor, constant: 24),

            step1Card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            step1Card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            step1Card.topAnchor.constraint(equalTo: div.bottomAnchor, constant: 20),

            step2Card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            step2Card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            step2Card.topAnchor.constraint(equalTo: step1Card.bottomAnchor, constant: 12),

            actionBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionBtn.topAnchor.constraint(equalTo: step2Card.bottomAnchor, constant: 32),
            actionBtn.heightAnchor.constraint(equalToConstant: 42),

            skip.centerXAnchor.constraint(equalTo: centerXAnchor),
            skip.topAnchor.constraint(equalTo: actionBtn.bottomAnchor, constant: 10),
        ])

        refreshState()
    }

    private func refreshState() {
        step1Done = FIFinderSyncController.isExtensionEnabled
        step2Done = AXIsProcessTrusted()
        updateCardHighlight(step1Card, done: step1Done, number: "1",
            title: NSLocalizedString("onboarding.step1.title", comment: ""),
            detail: step1Done ? NSLocalizedString("onboarding.step1.done", comment: "") : NSLocalizedString("onboarding.step1.detail", comment: ""))
        updateCardHighlight(step2Card, done: step2Done, number: "2",
            title: NSLocalizedString("onboarding.step2.title", comment: ""),
            detail: step2Done ? NSLocalizedString("onboarding.step2.done", comment: "") : NSLocalizedString("onboarding.step2.detail", comment: ""))

        if step1Done && step2Done {
            actionBtn.title = NSLocalizedString("onboarding.btn.done", comment: "")
            actionBtn.layer?.backgroundColor = NSColor.systemGreen.cgColor
        } else if step1Done {
            actionBtn.title = NSLocalizedString("onboarding.btn.step2", comment: "")
        } else {
            actionBtn.title = NSLocalizedString("onboarding.btn.step1", comment: "")
        }
    }

    @objc private func actionTapped() {
        if step1Done && step2Done {
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
            window?.close()
            NSApp.setActivationPolicy(.accessory)
            return
        }
        if !step1Done {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            FIFinderSyncController.showExtensionManagementInterface()
            startPolling()
        } else {
            if !AXIsProcessTrusted() {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(opts)
            } else {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            startPolling()
        }
    }

    @objc private func skipTapped() {
        window?.close()
        NSApp.setActivationPolicy(.accessory)
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshState()
            if self?.step1Done == true && self?.step2Done == true {
                self?.timer?.invalidate()
            }
        }
    }

    private func updateCardHighlight(_ card: NSView, done: Bool, number: String, title: String, detail: String) {
        let bgColor: NSColor = done
            ? NSColor.systemGreen.withAlphaComponent(0.12)
            : NSColor.controlAccentColor.withAlphaComponent(0.08)
        card.layer?.backgroundColor = bgColor.cgColor

        let labels = card.subviews.compactMap { $0 as? NSTextField }
        if let titleLabel = labels.first(where: { ($0.font?.pointSize ?? 0) > 12 }) {
            titleLabel.stringValue = title
        }
        if let detailLabel = labels.first(where: { ($0.font?.pointSize ?? 0) <= 12 }) {
            detailLabel.stringValue = detail
        }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, muted: Bool = false) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .systemFont(ofSize: size, weight: weight)
        f.textColor = muted ? .secondaryLabelColor : .labelColor
        f.alignment = .center
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func stepView(number: String, title: String, detail: String, highlight: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = highlight
            ? NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.15).cgColor
        container.layer?.cornerRadius = 10
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
        ])
        return container
    }
}
