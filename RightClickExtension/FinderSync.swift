import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync {

    let log = OSLog(subsystem: "gimomagic.RightClick-.RightClickExtension", category: "FinderSync")

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    private func loc(_ key: String) -> String {
        NSLocalizedString(key, bundle: Bundle(for: FinderSync.self), comment: "")
    }

    private var isPro: Bool {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return false }

        // Read from license.json
        let jsonURL = container.appendingPathComponent("license.json")
        if let data = try? Data(contentsOf: jsonURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard let plan = json["plan"] as? String, !plan.isEmpty else { return false }
            if let expiresStr = json["expiresAt"] as? String {
                let fmt = ISO8601DateFormatter()
                if let expiry = fmt.date(from: expiresStr) {
                    return expiry > Date()
                }
            }
            return true
        }
        return false
    }

    private func requirePro(_ action: () -> Void) {
        if isPro {
            action()
        } else {
            NSWorkspace.shared.open(URL(string: "rightclickplus://upgrade")!)
        }
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let hasSelection = menuKind == .contextualMenuForItems &&
            !(FIFinderSyncController.default().selectedItemURLs()?.isEmpty ?? true)

        if hasSelection {
            menu.addItem(makeItem(loc("menu.cut"), action: #selector(cutItems(_:)), symbol: "scissors", pro: true))
        }

        if hasPendingCut() {
            menu.addItem(makeItem(loc("menu.paste"), action: #selector(pasteItems(_:)), symbol: "doc.on.clipboard", pro: true))
        }

        let newItem = NSMenuItem(title: loc("menu.new"), action: nil, keyEquivalent: "")
        newItem.image = templateImage("document.badge.plus")
        let submenu = NSMenu(title: "")
        submenu.addItem(makeItem(loc("file.txt"),     action: #selector(createTxt(_:)),     symbol: "doc.text"))
        submenu.addItem(makeItem(loc("file.md"),      action: #selector(createMd(_:)),      symbol: "text.alignleft"))
        submenu.addItem(makeItem(loc("file.json"),    action: #selector(createJson(_:)),    symbol: "curlybraces"))
        submenu.addItem(makeItem(loc("file.csv"),     action: #selector(createCsv(_:)),     symbol: "tablecells"))
        submenu.addItem(makeItem(loc("file.html"),    action: #selector(createHtml(_:)),    symbol: "chevron.left.forwardslash.chevron.right"))
        submenu.addItem(makeItem(loc("file.py"),      action: #selector(createPy(_:)),      symbol: "terminal"))
        submenu.addItem(makeItem(loc("file.js"),      action: #selector(createJs(_:)),      symbol: "terminal"))
        submenu.addItem(makeItem(loc("file.swift"),   action: #selector(createSwift(_:)),   symbol: "swift"))
        submenu.addItem(makeItem(loc("file.sh"),      action: #selector(createSh(_:)),      symbol: "terminal"))
        submenu.addItem(makeItem(loc("file.docx"),    action: #selector(createDocx(_:)),    symbol: "doc.fill",                         pro: true))
        submenu.addItem(makeItem(loc("file.xlsx"),    action: #selector(createXlsx(_:)),    symbol: "tablecells",                       pro: true))
        submenu.addItem(makeItem(loc("file.pptx"),    action: #selector(createPptx(_:)),    symbol: "rectangle.on.rectangle",           pro: true))
        submenu.addItem(makeItem(loc("file.pages"),   action: #selector(createPages(_:)),   symbol: "doc.fill",                         pro: true))
        submenu.addItem(makeItem(loc("file.numbers"), action: #selector(createNumbers(_:)), symbol: "tablecells",                       pro: true))
        submenu.addItem(makeItem(loc("file.key"),     action: #selector(createKey(_:)),     symbol: "rectangle.on.rectangle",           pro: true))
        submenu.addItem(makeItem(loc("file.rtf"),     action: #selector(createRtf(_:)),     symbol: "doc.richtext",                     pro: true))
        newItem.submenu = submenu
        menu.addItem(newItem)

        // let hiddenVisible = UserDefaults(suiteName: "com.apple.finder")?
        //     .bool(forKey: "AppleShowAllFiles") ?? false
        // let toggleTitle = hiddenVisible ? loc("menu.toggleHidden.hide") : loc("menu.toggleHidden")
        // let toggleSymbol = hiddenVisible ? "eye.slash" : "eye"
        // menu.addItem(makeItem(toggleTitle, action: #selector(toggleHiddenFiles(_:)), symbol: toggleSymbol))

        return menu
    }

    private func makeItem(_ title: String, action: Selector, symbol: String, pro: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = templateImage(symbol)
        item.target = self
        if pro && !isPro {
            let attr = NSMutableAttributedString(string: title)
            let badge = NSAttributedString(string: "  Pro", attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .medium)
            ])
            attr.append(badge)
            item.attributedTitle = attr
        }
        return item
    }

    private func templateImage(_ symbol: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
        guard let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return nil }
        return img.withSymbolConfiguration(config)
    }

    // MARK: - Cortar

    @objc func cutItems(_ sender: Any?) {
        requirePro {
            guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else { return }
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
            let paths = items.map(\.path).joined(separator: "\n")
            try? "".write(to: container.appendingPathComponent("paste.txt"), atomically: false, encoding: .utf8)
            try? paths.write(to: container.appendingPathComponent("cut.txt"), atomically: false, encoding: .utf8)
            os_log("Cut %d items", log: self.log, items.count)
        }
    }

    // MARK: - Pegar

    @objc func pasteItems(_ sender: Any?) {
        requirePro {
            let target = FIFinderSyncController.default().targetedURL()
            let items = FIFinderSyncController.default().selectedItemURLs()
            let destination: URL
            if let first = items?.first, (try? first.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                destination = first
            } else if let t = target {
                destination = t
            } else { return }
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
            try? destination.path.write(to: container.appendingPathComponent("paste.txt"), atomically: false, encoding: .utf8)
            NSWorkspace.shared.open(URL(string: "rightclickplus://paste")!)
        }
    }

    // MARK: - Nuevo archivo (Free)

    @objc func createTxt(_ sender: Any?)     { writeCreate(ext: "txt") }
    @objc func createCsv(_ sender: Any?)     { writeCreate(ext: "csv") }
    @objc func createHtml(_ sender: Any?)    { writeCreate(ext: "html") }
    @objc func createPy(_ sender: Any?)      { writeCreate(ext: "py") }
    @objc func createJs(_ sender: Any?)      { writeCreate(ext: "js") }
    @objc func createSwift(_ sender: Any?)   { writeCreate(ext: "swift") }
    @objc func createSh(_ sender: Any?)      { writeCreate(ext: "sh") }
    @objc func createMd(_ sender: Any?)      { writeCreate(ext: "md") }
    @objc func createJson(_ sender: Any?)    { writeCreate(ext: "json") }

    // MARK: - Nuevo archivo (Pro)

    @objc func createRtf(_ sender: Any?)     { requirePro { self.writeCreate(ext: "rtf") } }
    @objc func createDocx(_ sender: Any?)    { requirePro { self.writeCreate(ext: "docx") } }
    @objc func createXlsx(_ sender: Any?)    { requirePro { self.writeCreate(ext: "xlsx") } }
    @objc func createPptx(_ sender: Any?)    { requirePro { self.writeCreate(ext: "pptx") } }
    @objc func createPages(_ sender: Any?)   { requirePro { self.writeCreate(ext: "pages") } }
    @objc func createNumbers(_ sender: Any?) { requirePro { self.writeCreate(ext: "numbers") } }
    @objc func createKey(_ sender: Any?)     { requirePro { self.writeCreate(ext: "key") } }

    private func writeCreate(ext: String) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        let folder: URL
        if let first = items?.first {
            folder = (try? first.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                ? first : first.deletingLastPathComponent()
        } else if let t = target {
            folder = t
        } else {
            folder = URL(fileURLWithPath: ("~/Desktop" as NSString).expandingTildeInPath)
        }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
        try? "\(folder.path)\n\(ext)".write(to: container.appendingPathComponent("pending.txt"), atomically: false, encoding: .utf8)
        NSWorkspace.shared.open(URL(string: "rightclickplus://create")!)
    }

    // MARK: - Archivos ocultos

    @objc func toggleHiddenFiles(_ sender: Any?) {
        let defaults = UserDefaults(suiteName: "com.apple.finder")
        let current = defaults?.bool(forKey: "AppleShowAllFiles") ?? false
        defaults?.set(!current, forKey: "AppleShowAllFiles")
        defaults?.synchronize()
        // Restart Finder to apply
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Finder"]
        try? task.run()
    }

    // MARK: - Helpers

    private func hasPendingCut() -> Bool {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return false }
        let content = (try? String(contentsOf: container.appendingPathComponent("cut.txt"), encoding: .utf8)) ?? ""
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
