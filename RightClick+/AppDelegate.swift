import Cocoa
import FinderSync
import ServiceManagement
import os

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var pollTimer: Timer?
    let log = OSLog(subsystem: "gimomagic.RightClick-", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
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

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "RightClick+")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "RightClick+ activo", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
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

        // Clear immediately to avoid double-processing
        try? "".write(to: queueFile, atomically: false, encoding: .utf8)

        let folder = URL(fileURLWithPath: folderPath)
        var fileURL = folder.appendingPathComponent("Sin título.txt")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("Sin título \(counter).txt")
            counter += 1
        }

        do {
            try "".write(to: fileURL, atomically: false, encoding: .utf8)
            os_log("Created: %{public}@", log: log, fileURL.path)
            beginRename(fileURL)
        } catch {
            os_log("ERROR: %{public}@", log: log, error.localizedDescription)
        }
    }

    func beginRename(_ fileURL: URL) {
        let path = fileURL.path
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Bring Finder to front and select the file
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])

            // After Finder is focused and file is selected, send Return via CGEvent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                // Find Finder's PID to target the keypress directly
                let finderApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                guard let finder = finderApps.first else { return }

                let src = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: true) // Return
                let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: false)
                keyDown?.postToPid(finder.processIdentifier)
                keyUp?.postToPid(finder.processIdentifier)
                os_log("Sent Return to Finder pid=%d for %{public}@", log: self.log, finder.processIdentifier, path)
            }
        }
    }
}
