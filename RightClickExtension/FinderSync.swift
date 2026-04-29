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
            folder = URL(fileURLWithPath: NSHomeDirectory())
        }

        os_log("folder: %{public}@", log: log, folder.path)

        var fileURL = folder.appendingPathComponent("Sin título.txt")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("Sin título \(counter).txt")
            counter += 1
        }

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            os_log("Successfully created file directly: %{public}@", log: log, fileURL.path)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            os_log("ERROR creating file: %{public}@", log: log, error.localizedDescription)
            
            // Fallback to Main App via pending.txt if direct creation fails
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }
            let queueFile = container.appendingPathComponent("pending.txt")
            try? folder.path.write(to: queueFile, atomically: true, encoding: .utf8)
            
            // Wake up the main app if it's closed
            if let url = URL(string: "rightclickplus://") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
