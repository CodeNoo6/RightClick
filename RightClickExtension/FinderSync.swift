import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync {

    let log = OSLog(subsystem: "gimomagic.RightClick-.RightClickExtension", category: "FinderSync")

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    private var isSpanish: Bool {
        Locale.current.language.languageCode?.identifier == "es"
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let hasSelection = menuKind == .contextualMenuForItems &&
            !(FIFinderSyncController.default().selectedItemURLs()?.isEmpty ?? true)

        if hasSelection {
            menu.addItem(makeItem(isSpanish ? "Cortar" : "Cut", action: #selector(cutItems(_:)), symbol: "scissors"))
        }

        if hasPendingCut() {
            menu.addItem(makeItem(isSpanish ? "Pegar elemento" : "Paste Item", action: #selector(pasteItems(_:)), symbol: "doc.on.clipboard"))
        }

        let newItem = NSMenuItem(title: isSpanish ? "Nuevo" : "New", action: nil, keyEquivalent: "")
        newItem.image = templateImage("plus")
        let submenu = NSMenu(title: "")
        submenu.addItem(makeItem(isSpanish ? "Archivo de texto (.txt)" : "Text File (.txt)", action: #selector(createTxt(_:)), symbol: "doc.text"))
        submenu.addItem(makeItem(isSpanish ? "Markdown (.md)" : "Markdown (.md)", action: #selector(createMd(_:)), symbol: "text.alignleft"))
        submenu.addItem(makeItem(isSpanish ? "Documento Word (.docx)" : "Word Document (.docx)", action: #selector(createDocx(_:)), symbol: "doc.fill"))
        submenu.addItem(makeItem(isSpanish ? "Hoja Excel (.xlsx)" : "Excel Spreadsheet (.xlsx)", action: #selector(createXlsx(_:)), symbol: "tablecells"))
        submenu.addItem(makeItem(isSpanish ? "Presentación PowerPoint (.pptx)" : "PowerPoint (.pptx)", action: #selector(createPptx(_:)), symbol: "rectangle.on.rectangle"))
        submenu.addItem(makeItem(isSpanish ? "Documento Pages (.pages)" : "Pages Document (.pages)", action: #selector(createPages(_:)), symbol: "doc.fill"))
        submenu.addItem(makeItem(isSpanish ? "Hoja Numbers (.numbers)" : "Numbers Spreadsheet (.numbers)", action: #selector(createNumbers(_:)), symbol: "tablecells"))
        submenu.addItem(makeItem(isSpanish ? "Presentación Keynote (.key)" : "Keynote Presentation (.key)", action: #selector(createKey(_:)), symbol: "rectangle.on.rectangle"))
        submenu.addItem(makeItem(isSpanish ? "Archivo JSON (.json)" : "JSON File (.json)", action: #selector(createJson(_:)), symbol: "curlybraces"))
        submenu.addItem(makeItem(isSpanish ? "Archivo CSV (.csv)" : "CSV File (.csv)", action: #selector(createCsv(_:)), symbol: "tablecells"))
        submenu.addItem(makeItem(isSpanish ? "Archivo HTML (.html)" : "HTML File (.html)", action: #selector(createHtml(_:)), symbol: "chevron.left.forwardslash.chevron.right"))
        submenu.addItem(makeItem(isSpanish ? "Script Python (.py)" : "Python Script (.py)", action: #selector(createPy(_:)), symbol: "terminal"))
        submenu.addItem(makeItem(isSpanish ? "Archivo JavaScript (.js)" : "JavaScript (.js)", action: #selector(createJs(_:)), symbol: "terminal"))
        submenu.addItem(makeItem(isSpanish ? "Archivo Swift (.swift)" : "Swift File (.swift)", action: #selector(createSwift(_:)), symbol: "swift"))
        submenu.addItem(makeItem(isSpanish ? "Script Shell (.sh)" : "Shell Script (.sh)", action: #selector(createSh(_:)), symbol: "terminal"))
        submenu.addItem(makeItem(isSpanish ? "Texto enriquecido (.rtf)" : "Rich Text (.rtf)", action: #selector(createRtf(_:)), symbol: "doc.richtext"))
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
