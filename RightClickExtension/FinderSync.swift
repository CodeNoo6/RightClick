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

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let hasSelection = menuKind == .contextualMenuForItems &&
            !(FIFinderSyncController.default().selectedItemURLs()?.isEmpty ?? true)

        if hasSelection {
            menu.addItem(makeItem(loc("menu.cut"), action: #selector(cutItems(_:)), symbol: "scissors"))
        }

        if hasPendingCut() {
            menu.addItem(makeItem(loc("menu.paste"), action: #selector(pasteItems(_:)), symbol: "doc.on.clipboard"))
        }

        let newItem = NSMenuItem(title: loc("menu.new"), action: nil, keyEquivalent: "")
        newItem.image = templateImage("document.badge.plus")
        let submenu = NSMenu(title: "")
        submenu.addItem(makeItem(loc("file.txt"),     action: #selector(createTxt(_:)),     symbol: "doc.text"))
        submenu.addItem(makeItem(loc("file.md"),      action: #selector(createMd(_:)),      symbol: "text.alignleft"))
        submenu.addItem(makeItem(loc("file.docx"),    action: #selector(createDocx(_:)),    symbol: "doc.fill"))
        submenu.addItem(makeItem(loc("file.xlsx"),    action: #selector(createXlsx(_:)),    symbol: "tablecells"))
        submenu.addItem(makeItem(loc("file.pptx"),    action: #selector(createPptx(_:)),    symbol: "rectangle.on.rectangle"))
        submenu.addItem(makeItem(loc("file.pages"),   action: #selector(createPages(_:)),   symbol: "doc.fill"))
        submenu.addItem(makeItem(loc("file.numbers"), action: #selector(createNumbers(_:)), symbol: "tablecells"))
        submenu.addItem(makeItem(loc("file.key"),     action: #selector(createKey(_:)),     symbol: "rectangle.on.rectangle"))
        submenu.addItem(makeItem(loc("file.json"),    action: #selector(createJson(_:)),    symbol: "curlybraces"))
        submenu.addItem(makeItem(loc("file.csv"),     action: #selector(createCsv(_:)),     symbol: "tablecells"))
        submenu.addItem(makeItem(loc("file.html"),    action: #selector(createHtml(_:)),    symbol: "chevron.left.forwardslash.chevron.right"))
        submenu.addItem(makeItem(loc("file.py"),      action: #selector(createPy(_:)),      symbol: "terminal"))
        submenu.addItem(makeItem(loc("file.js"),      action: #selector(createJs(_:)),      symbol: "terminal"))
        submenu.addItem(makeItem(loc("file.swift"),   action: #selector(createSwift(_:)),   symbol: "swift"))
        submenu.addItem(makeItem(loc("file.sh"),      action: #selector(createSh(_:)),      symbol: "terminal"))
        submenu.addItem(makeItem(loc("file.rtf"),     action: #selector(createRtf(_:)),     symbol: "doc.richtext"))
        newItem.submenu = submenu
        menu.addItem(newItem)

        return menu
    }

    private func makeItem(_ title: String, action: Selector, symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = templateImage(symbol)
        item.target = self
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
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else { return }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
        let paths = items.map(\.path).joined(separator: "\n")
        try? "".write(to: container.appendingPathComponent("paste.txt"), atomically: false, encoding: .utf8)
        try? paths.write(to: container.appendingPathComponent("cut.txt"), atomically: false, encoding: .utf8)
        os_log("Cut %d items", log: log, items.count)
    }

    // MARK: - Pegar

    @objc func pasteItems(_ sender: Any?) {
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

    // MARK: - Nuevo archivo

    @objc func createTxt(_ sender: Any?)     { writeCreate(ext: "txt") }
    @objc func createRtf(_ sender: Any?)     { writeCreate(ext: "rtf") }
    @objc func createCsv(_ sender: Any?)     { writeCreate(ext: "csv") }
    @objc func createHtml(_ sender: Any?)    { writeCreate(ext: "html") }
    @objc func createPy(_ sender: Any?)      { writeCreate(ext: "py") }
    @objc func createJs(_ sender: Any?)      { writeCreate(ext: "js") }
    @objc func createSwift(_ sender: Any?)   { writeCreate(ext: "swift") }
    @objc func createSh(_ sender: Any?)      { writeCreate(ext: "sh") }
    @objc func createMd(_ sender: Any?)      { writeCreate(ext: "md") }
    @objc func createDocx(_ sender: Any?)    { writeCreate(ext: "docx") }
    @objc func createXlsx(_ sender: Any?)    { writeCreate(ext: "xlsx") }
    @objc func createPptx(_ sender: Any?)    { writeCreate(ext: "pptx") }
    @objc func createPages(_ sender: Any?)   { writeCreate(ext: "pages") }
    @objc func createNumbers(_ sender: Any?) { writeCreate(ext: "numbers") }
    @objc func createKey(_ sender: Any?)     { writeCreate(ext: "key") }
    @objc func createJson(_ sender: Any?)    { writeCreate(ext: "json") }

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

    // MARK: - Helpers

    private func hasPendingCut() -> Bool {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return false }
        let content = (try? String(contentsOf: container.appendingPathComponent("cut.txt"), encoding: .utf8)) ?? ""
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
