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
        handlePendingFile()
    }

    func checkExtensionEnabled() {
        if !FIFinderSyncController.isExtensionEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        }
    }

    // MARK: - File Creation

    func handlePendingFile() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let queueFile = container.appendingPathComponent("pending.txt")
        guard let raw = try? String(contentsOf: queueFile, encoding: .utf8), !raw.isEmpty else { return }
        let folderPath = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderPath.isEmpty else { return }

        try? "".write(to: queueFile, atomically: false, encoding: .utf8)
        createFile(in: URL(fileURLWithPath: folderPath))
    }

    func createFile(in folder: URL) {
        var fileURL = folder.appendingPathComponent("Sin título.txt")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("Sin título \(counter).txt")
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
