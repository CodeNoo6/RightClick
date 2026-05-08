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
            button.image = makeMenuBarMouseIcon()
        }
        let menu = NSMenu()
        let title = NSMenuItem(title: "RightClick+", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        // let uninstall = NSMenuItem(title: "Uninstall RightClick+…", action: #selector(uninstallApp), keyEquivalent: "")
        // uninstall.target = self
        // menu.addItem(uninstall)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func uninstallApp() {
        let alert = NSAlert()
        alert.messageText = "Uninstall RightClick+?"
        alert.informativeText = "This will completely remove the app, all data, permissions, and login item registration."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.setActivationPolicy(.accessory)
            return
        }

        // 1. Unregister login item
        try? SMAppService.mainApp.unregister()

        // 2. Clear UserDefaults (main app + shared suite)
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        UserDefaults(suiteName: "653RS235MN.gimomagic.RightClick")?.removePersistentDomain(forName: "653RS235MN.gimomagic.RightClick")

        // 3. Remove App Group container data
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") {
            try? FileManager.default.removeItem(at: container)
        }

        // 4. Full cleanup via shell with admin: app, caches, prefs, saved state, TCC reset
        let bundleID = "gimomagic.RightClick-"
        let extBundleID = "gimomagic.RightClick-.RightClickExtension"
        let home = NSHomeDirectory()

        let cmds = [
            // App bundle
            "rm -rf /Applications/RightClick+.app",
            // Preferences
            "rm -f \(home)/Library/Preferences/\(bundleID).plist",
            "rm -f \(home)/Library/Preferences/\(extBundleID).plist",
            // Caches
            "rm -rf \(home)/Library/Caches/\(bundleID)",
            "rm -rf \(home)/Library/Caches/\(extBundleID)",
            // Saved Application State
            "rm -rf \(home)/Library/Saved\\ Application\\ State/\(bundleID).savedState",
            // Application Support
            "rm -rf \(home)/Library/Application\\ Support/\(bundleID)",
            // Revoke Accessibility permission from TCC database
            "tccutil reset Accessibility \(bundleID)",
            "tccutil reset Accessibility \(extBundleID)",
            // Revoke all other TCC permissions
            "tccutil reset All \(bundleID)",
            "tccutil reset All \(extBundleID)",
        ].joined(separator: "; ")

        let script = "do shell script \"\(cmds.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        NSAppleScript(source: script)?.executeAndReturnError(nil)

        NSApp.terminate(nil)
    }

    func makeMenuBarMouseIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let outline = NSImage(systemSymbolName: "computermouse", accessibilityDescription: nil)?
                .withSymbolConfiguration(config),
              let filled = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else { return NSImage() }

        let size = outline.size

        // Render a source image as black mask
        func mask(_ src: NSImage) -> NSImage {
            let img = NSImage(size: size)
            img.lockFocus()
            NSColor.black.set()
            NSRect(origin: .zero, size: size).fill()
            src.draw(in: NSRect(origin: .zero, size: size),
                     from: .zero, operation: .destinationIn, fraction: 1)
            img.unlockFocus()
            return img
        }

        let outlineMask = mask(outline)
        let filledMask  = mask(filled)

        let splitX = size.width / 2
        let splitY = size.height * 0.55

        let result = NSImage(size: size)
        result.lockFocus()

        // 1. Outline completo (silueta del mouse)
        outlineMask.draw(in: NSRect(origin: .zero, size: size))

        // 2. Relleno solo en botón derecho (mitad derecha, zona superior)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: splitX, y: splitY, width: size.width - splitX, height: size.height - splitY)).addClip()
        filledMask.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        result.unlockFocus()
        result.isTemplate = true  // el sistema aplica blanco/negro según el tema
        return result
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
        let fullySetUp = FIFinderSyncController.isExtensionEnabled && AXIsProcessTrusted()
            && UserDefaults.standard.bool(forKey: "onboardingComplete")
        if !fullySetUp {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                OnboardingWindowController.shared.showWindow(nil)
                OnboardingWindowController.shared.window?.center()
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
        let baseName = NSLocalizedString("file.untitled", comment: "")
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

        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: select the file inside whatever Finder window is already showing the folder
            let selectScript = """
            tell application "Finder"
                set theFile to POSIX file "\(path)" as alias
                select theFile
                activate
            end tell
            """
            var err1: NSDictionary?
            NSAppleScript(source: selectScript)?.executeAndReturnError(&err1)
            os_log("select err=%{public}@", log: self.log, "\(err1 as Any)")

            // Wait for Finder to process the selection
            Thread.sleep(forTimeInterval: 0.4)

            // Step 2: send Enter (keycode 36) to enter rename mode — only if Finder is frontmost
            let renameScript = """
            tell application "System Events"
                tell process "Finder"
                    set frontmost to true
                    key code 36
                end tell
            end tell
            """
            var err2: NSDictionary?
            NSAppleScript(source: renameScript)?.executeAndReturnError(&err2)
            os_log("rename err=%{public}@", log: self.log, "\(err2 as Any)")
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
