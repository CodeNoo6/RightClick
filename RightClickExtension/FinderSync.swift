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

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")

        let newItem = NSMenuItem(title: "Nuevo", action: nil, keyEquivalent: "")
        newItem.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        let submenu = NSMenu(title: "")

        let txtItem = NSMenuItem(title: "Archivo de texto (.txt)", action: #selector(createTxt(_:)), keyEquivalent: "")
        txtItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        txtItem.target = self
        submenu.addItem(txtItem)

        newItem.submenu = submenu
        menu.addItem(newItem)

        return menu
    }

    @objc func createTxt(_ sender: Any?) {
        os_log("createTxt called", log: log)

        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()

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

        os_log("folder: %{public}@", log: log, folder.path)

        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else {
            os_log("ERROR: no container", log: log)
            return
        }

        let queueFile = container.appendingPathComponent("pending.txt")
        do {
            try folder.path.write(to: queueFile, atomically: false, encoding: .utf8)
            os_log("Written to pending.txt: %{public}@", log: log, folder.path)
        } catch {
            os_log("ERROR writing pending.txt: %{public}@", log: log, error.localizedDescription)
        }

        if let url = URL(string: "rightclickplus://create") {
            NSWorkspace.shared.open(url)
        }
    }
}
