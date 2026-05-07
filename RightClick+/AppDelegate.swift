import Cocoa
import FinderSync
import ServiceManagement
import os

class AppDelegate: NSObject, NSApplicationDelegate {
    let log = OSLog(subsystem: "gimomagic.RightClick-", category: "AppDelegate")
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerLoginItem()
        checkExtensionEnabled()
        DispatchQueue.main.async {
            self.setupMenuBar()
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "contextualmenu.and.cursorarrow", accessibilityDescription: "RightClick+")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        let title = NSMenuItem(title: "RightClick+", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // Called by the extension via rightclickplus:// URL scheme
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let host = url.host else { continue }
            switch host {
            case "create": handleCreate(url: url)
            case "paste":  handlePaste(url: url)
            default: break
            }
        }
    }

    func checkExtensionEnabled() {
        if !FIFinderSyncController.isExtensionEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                FIFinderSyncController.showExtensionManagementInterface()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    func registerLoginItem() {
        try? SMAppService.mainApp.register()
    }

    // MARK: - Create

    func handleCreate(url: URL) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let queueFile = container.appendingPathComponent("pending.txt")
        guard let raw = try? String(contentsOf: queueFile, encoding: .utf8), !raw.isEmpty else { return }

        // Clear immediately before doing anything else
        try? "".write(to: queueFile, atomically: true, encoding: .utf8)

        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let folderPath = lines.first else { return }
        let ext = lines.count > 1 ? lines[1] : "txt"

        createFile(in: URL(fileURLWithPath: folderPath), ext: ext)
    }

    func createFile(in folder: URL, ext: String = "txt") {
        let baseName = Locale.current.language.languageCode?.identifier == "es" ? "Sin título" : "Untitled"
        var fileURL = folder.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("\(baseName) \(counter).\(ext)")
            counter += 1
        }

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            os_log("Created: %{public}@", log: log, fileURL.path)
            selectAndRename(fileURL)
        } catch {
            os_log("ERROR creating: %{public}@", log: log, error.localizedDescription)
        }
    }

    func selectAndRename(_ fileURL: URL) {
        let path = fileURL.path
        let folder = fileURL.deletingLastPathComponent().path

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return }

            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: folder)
            finder.activate(options: .activateIgnoringOtherApps)

            // Poll until Finder is actually the frontmost app, then send Return
            self.sendReturnWhenFinderIsFront(finderPID: finder.processIdentifier, attempts: 10)
        }
    }

    private func sendReturnWhenFinderIsFront(finderPID: pid_t, attempts: Int) {
        guard attempts > 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let front = NSWorkspace.shared.frontmostApplication,
                  front.processIdentifier == finderPID else {
                // Finder not front yet, retry
                self.sendReturnWhenFinderIsFront(finderPID: finderPID, attempts: attempts - 1)
                return
            }
            let src = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: true)
            let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: false)
            keyDown?.postToPid(finderPID)
            keyUp?.postToPid(finderPID)
            os_log("Sent Return to Finder (frontmost)", log: self.log)
        }
    }

    // MARK: - Paste

    func handlePaste(url: URL) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let cutFile = container.appendingPathComponent("cut.txt")
        let pasteFile = container.appendingPathComponent("paste.txt")

        guard let cutRaw = try? String(contentsOf: cutFile, encoding: .utf8), !cutRaw.isEmpty,
              let destRaw = try? String(contentsOf: pasteFile, encoding: .utf8), !destRaw.isEmpty else { return }

        try? "".write(to: cutFile, atomically: true, encoding: .utf8)
        try? "".write(to: pasteFile, atomically: true, encoding: .utf8)

        let sources = cutRaw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let destination = URL(fileURLWithPath: destRaw.trimmingCharacters(in: .whitespacesAndNewlines))

        var movedURLs: [URL] = []
        var errors: [String] = []

        for sourcePath in sources {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destURL = destination.appendingPathComponent(sourceURL.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destURL)
                movedURLs.append(destURL)
                os_log("Moved: %{public}@ -> %{public}@", log: log, sourcePath, destURL.path)
            } catch {
                errors.append("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
                os_log("ERROR moving: %{public}@", log: log, error.localizedDescription)
            }
        }

        if !movedURLs.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSWorkspace.shared.activateFileViewerSelecting(movedURLs)
            }
        }

        if !errors.isEmpty {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error al mover"
                alert.informativeText = errors.joined(separator: "\n")
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
