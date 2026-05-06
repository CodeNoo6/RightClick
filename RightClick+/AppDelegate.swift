import Cocoa
import FinderSync
import ServiceManagement
import os

class AppDelegate: NSObject, NSApplicationDelegate {
    var pollTimer: Timer?
    let log = OSLog(subsystem: "gimomagic.RightClick-", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()
        startPolling()
        checkExtensionEnabled()
    }

    // Called by the extension via rightclickplus:// URL scheme
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "create": handlePendingFile()
            case "paste":  handlePaste()
            default:       handlePendingFile()
            }
        }
    }

    func checkExtensionEnabled() {
        if !FIFinderSyncController.isExtensionEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                FIFinderSyncController.showExtensionManagementInterface()
            }
        }
    }

    // MARK: - Login Item

    func registerLoginItem() {
        try? SMAppService.mainApp.register()
    }

    // MARK: - Polling

    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.handlePendingFile()
            self?.handlePaste()
        }
    }

    // MARK: - Paste (move cut items)

    func handlePaste() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let cutFile = container.appendingPathComponent("cut.txt")
        let pasteFile = container.appendingPathComponent("paste.txt")

        guard let cutRaw = try? String(contentsOf: cutFile, encoding: .utf8), !cutRaw.isEmpty,
              let destRaw = try? String(contentsOf: pasteFile, encoding: .utf8), !destRaw.isEmpty else { return }

        // Clear immediately
        try? "".write(to: cutFile, atomically: false, encoding: .utf8)
        try? "".write(to: pasteFile, atomically: false, encoding: .utf8)

        let sources = cutRaw.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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

        // Select moved items in Finder
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

    // MARK: - File Creation

    func handlePendingFile() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let queueFile = container.appendingPathComponent("pending.txt")
        guard let raw = try? String(contentsOf: queueFile, encoding: .utf8), !raw.isEmpty else { return }
        let lines = raw.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let folderPath = lines.first, !folderPath.isEmpty else { return }
        let ext = lines.count > 1 ? lines[1] : "txt"

        try? "".write(to: queueFile, atomically: false, encoding: .utf8)
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
            try "".write(to: fileURL, atomically: false, encoding: .utf8)
            os_log("Created: %{public}@", log: log, fileURL.path)
            selectAndRename(fileURL)
        } catch {
            os_log("ERROR: %{public}@", log: log, error.localizedDescription)
        }
    }

    func selectAndRename(_ fileURL: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Select the file in Finder without activating/switching the app
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)

            // Send Return key to Finder to trigger inline rename
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return }
                let src = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: true)
                let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: false)
                keyDown?.postToPid(finder.processIdentifier)
                keyUp?.postToPid(finder.processIdentifier)
            }
        }
    }
}
