import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync {

    let log = OSLog(subsystem: "gimomagic.RightClick-.RightClickExtension", category: "FinderSync")

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        os_log("FinderSync init", log: log)
    }

    override var toolbarItemName: String { return "RightClick+" }
    override var toolbarItemToolTip: String { return "RightClick+" }
    override var toolbarItemImage: NSImage { return NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil) ?? NSImage() }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        os_log("menu(for:) called kind=%d", log: log, menuKind.rawValue)
        let menu = NSMenu(title: "")
        let txtItem = NSMenuItem(title: "Nuevo archivo .txt", action: #selector(createTxt(_:)), keyEquivalent: "")
        txtItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        txtItem.target = self
        menu.addItem(txtItem)
        return menu
    }

    @objc func createTxt(_ sender: Any?) {
        os_log("createTxt called", log: log)

        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()

        os_log("targetedURL: %{public}@", log: log, target?.path ?? "nil")
        os_log("selectedItems: %{public}@", log: log, items?.map(\.path).joined(separator: ", ") ?? "nil")

        let folder: URL
        if let first = items?.first {
            if (try? first.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                folder = first
            } else {
                folder = first.deletingLastPathComponent()
            }
        } else if let t = target {
            folder = t
        } else {
            folder = URL(fileURLWithPath: ("~/Desktop" as NSString).expandingTildeInPath)
        }

        os_log("folder resolved: %{public}@", log: log, folder.path)

        // Always delegate to main app — it has Full Disk Access and Accessibility
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
        let queueFile = container.appendingPathComponent("pending.txt")
        try? folder.path.write(to: queueFile, atomically: true, encoding: .utf8)

        if let url = URL(string: "rightclickplus://") {
            NSWorkspace.shared.open(url)
        }
    }
}
