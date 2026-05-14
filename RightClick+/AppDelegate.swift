import Cocoa
import FinderSync
import ServiceManagement
import Sparkle
import os

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let log = OSLog(subsystem: "gimomagic.RightClick-", category: "AppDelegate")
    var statusItem: NSStatusItem?
    var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        registerLoginItem()
        setupMenuBar()
        checkExtensionEnabled()
        LicenseManager.shared.revalidate()

        NotificationCenter.default.addObserver(forName: LicenseManager.licenseUpdatedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshPlanItemTitle()
            self?.checkLicenseExpiry()
        }

        // Revalidate every 12 hours automatically
        Timer.scheduledTimer(withTimeInterval: 43200, repeats: true) { _ in
            LicenseManager.shared.revalidate()
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = makeMenuBarMouseIcon()
        }
        
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem?.menu = menu
        
        buildMenu(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        LicenseManager.shared.revalidate()
    }

    func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let aboutItem = NSMenuItem(title: NSLocalizedString("menu.about", comment: ""), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionItem = NSMenuItem(title: String(format: NSLocalizedString("menu.version", comment: ""), version), action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let planItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        planItem.tag = 99 // Etiqueta para encontrarlo luego
        planItem.target = self
        menu.addItem(planItem)
        refreshPlanItemTitle()

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: NSLocalizedString("menu.checkForUpdates", comment: ""), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        updateItem.isEnabled = true
        menu.addItem(updateItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.isEnabled = true
        menu.addItem(quitItem)
    }

    func refreshPlanItemTitle() {
        guard let menu = statusItem?.menu, let planItem = menu.item(withTag: 99) else { return }
        
        let isPro = LicenseManager.shared.isPro
        let planTitle: String
        if isPro {
            switch LicenseManager.shared.plan {
            case .monthly:
                let days = LicenseManager.shared.daysRemaining ?? 0
                planTitle = String(format: NSLocalizedString("menu.plan.monthly", comment: ""), days)
            case .annual:
                let days = LicenseManager.shared.daysRemaining ?? 0
                planTitle = String(format: NSLocalizedString("menu.plan.annual", comment: ""), days)
            default:
                planTitle = NSLocalizedString("menu.plan.lifetime", comment: "")
            }
        } else {
            planTitle = NSLocalizedString("menu.plan.free", comment: "")
        }
        
        planItem.title = planTitle
        planItem.action = isPro ? nil : #selector(openUpgrade)
        planItem.isEnabled = true
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
            // Flush preferences daemon cache
            "killall cfprefsd",
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
            case "create":  
                LicenseManager.shared.revalidate()
                handleCreate(url: url)
            case "paste":   
                LicenseManager.shared.revalidate()
                handlePaste(url: url)
            case "upgrade": UpgradeWindowController.shared.show()
            default: break
            }
        }
    }

    func checkExtensionEnabled() {
        let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingComplete")
        if onboardingDone {
            NSApp.setActivationPolicy(.accessory)
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        OnboardingWindowController.shared.showWindow(nil)
        OnboardingWindowController.shared.window?.makeKeyAndOrderFront(nil)
        OnboardingWindowController.shared.window?.center()
    }

    func registerLoginItem() {
        try? SMAppService.mainApp.register()
    }

    func checkLicenseExpiry() {
        guard let days = LicenseManager.shared.daysRemaining, days <= 2 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            if days == 0 {
                alert.messageText = NSLocalizedString("license.expiry.today.title", comment: "")
                alert.informativeText = NSLocalizedString("license.expiry.today.body", comment: "")
            } else {
                alert.messageText = String(format: NSLocalizedString("license.expiry.soon.title", comment: ""), days)
                alert.informativeText = NSLocalizedString("license.expiry.soon.body", comment: "")
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("license.expiry.renew", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("license.expiry.dismiss", comment: ""))

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://rightclickmac.com/#pricing")!)
            }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func showAbout() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func openUpgrade() {
        UpgradeWindowController.shared.show()
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
            switch ext {
            case "pages", "numbers", "key":
                createIWorkFile(at: fileURL, ext: ext)
                return
            case "xlsx":
                try Data(base64Encoded: "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")!.write(to: fileURL)
            case "docx":
                try Data(base64Encoded: "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")!.write(to: fileURL)
            case "pptx":
                try Data(base64Encoded: "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")!.write(to: fileURL)
            case "rtf":
                let rtf = "{\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0 Helvetica;}} \\pard\\f0\\fs24 }"
                try rtf.write(to: fileURL, atomically: true, encoding: .utf8)
            default:
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
            }
            os_log("Created: %{public}@", log: log, fileURL.path)
            selectAndRename(fileURL)
        } catch {
            os_log("ERROR creating: %{public}@", log: log, error.localizedDescription)
        }
    }

    private func createIWorkFile(at fileURL: URL, ext: String) {
        let bundleID: String
        let appName: String
        switch ext {
        case "pages":   bundleID = "com.apple.iWork.Pages";   appName = "Pages"
        case "numbers": bundleID = "com.apple.iWork.Numbers"; appName = "Numbers"
        default:        bundleID = "com.apple.iWork.Keynote"; appName = "Keynote"
        }

        // Check the app is installed before trying AppleScript
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "\(appName) is not installed"
                alert.informativeText = "\(appName) is required to create .\(ext) files. Download it for free from the App Store."
                alert.addButton(withTitle: "Open App Store")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    let storeURLs: [String: String] = [
                        "pages":   "macappstore://itunes.apple.com/app/id409201541",
                        "numbers": "macappstore://itunes.apple.com/app/id409203825",
                        "key":     "macappstore://itunes.apple.com/app/id409183694",
                    ]
                    if let urlStr = storeURLs[ext], let url = URL(string: urlStr) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        let path = fileURL.path.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application id "\(bundleID)"
            set d to make new document
            save d in POSIX file "\(path)"
            close d saving no
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if error == nil && FileManager.default.fileExists(atPath: fileURL.path) {
                    os_log("IWork created: %{public}@", log: self.log, fileURL.path)
                    self.selectAndRename(fileURL)
                } else {
                    os_log("IWork error: %{public}@", log: self.log, "\(error as Any)")
                }
            }
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
