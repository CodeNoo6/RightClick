import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync {

    let log = OSLog(subsystem: "gimomagic.RightClick-.RightClickExtension", category: "FinderSync")

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let hasSelection = !(FIFinderSyncController.default().selectedItemURLs()?.isEmpty ?? true)

        if hasSelection {
            menu.addItem(makeItem("Cortar", action: #selector(cutItems(_:)), symbol: "scissors"))
        }

        if hasPendingCut() {
            menu.addItem(makeItem("Pegar elemento", action: #selector(pasteItems(_:)), symbol: "doc.on.clipboard"))
        }

        if hasSelection || hasPendingCut() {
            menu.addItem(.separator())
        }

        let newItem = NSMenuItem(title: "Nuevo", action: nil, keyEquivalent: "")
        newItem.image = templateImage("plus")
        let submenu = NSMenu(title: "")
        submenu.addItem(makeItem("Archivo de texto (.txt)", action: #selector(createTxt(_:)), symbol: "doc.text"))
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
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        guard let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return nil }
        return img.withSymbolConfiguration(config)
    }

    // MARK: - Cortar

    @objc func cutItems(_ sender: Any?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(), !items.isEmpty else { return }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let paths = items.map(\.path).joined(separator: "\n")
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
        } else {
            return
        }

        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
        try? destination.path.write(to: container.appendingPathComponent("paste.txt"), atomically: false, encoding: .utf8)

        NSWorkspace.shared.open(URL(string: "rightclickplus://paste")!)
    }

    // MARK: - Nuevo archivo

    @objc func createTxt(_ sender: Any?) {
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
        try? folder.path.write(to: container.appendingPathComponent("pending.txt"), atomically: false, encoding: .utf8)
        NSWorkspace.shared.open(URL(string: "rightclickplus://create")!)
    }

    // MARK: - Helpers

    private func hasPendingCut() -> Bool {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return false }
        let content = (try? String(contentsOf: container.appendingPathComponent("cut.txt"), encoding: .utf8)) ?? ""
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
