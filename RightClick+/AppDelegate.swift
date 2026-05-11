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
