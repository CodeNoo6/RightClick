import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var eventStream: FSEventStreamRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerLoginItem()
        watchSharedContainer()
        triggerPrivacyPrompts()
    }
    
    func triggerPrivacyPrompts() {
        // Obsolete
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

    // MARK: - File Watcher

    func watchSharedContainer() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let path = container.path as CFString
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)

        eventStream = FSEventStreamCreate(nil, { _, info, _, _, _, _ in
            guard let info else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            delegate.handlePendingFile()
        }, &context, [path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1, FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents))

        if let stream = eventStream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    func handlePendingFile() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") else { return }

        let queueFile = container.appendingPathComponent("pending.txt")
        guard let folderPathRaw = try? String(contentsOf: queueFile, encoding: .utf8), !folderPathRaw.isEmpty else { return }
        let folderPath = folderPathRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderPath.isEmpty else { return }

        do {
            try "".write(to: queueFile, atomically: true, encoding: .utf8)
        } catch {
            print("Error clearing pending file: \(error)")
        }

        let folder = URL(fileURLWithPath: folderPath)
        var fileURL = folder.appendingPathComponent("Sin título.txt")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = folder.appendingPathComponent("Sin título \(counter).txt")
            counter += 1
        }

        print("Attempting to create file in folder: \(folderPath)")
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully created file: \(fileURL.path)")
            NSWorkspace.shared.open(fileURL)
        } catch {
            print("CRITICAL Error creating file at \(fileURL.path): \(error)")
            let errorDesc = error.localizedDescription
            
            // Fallback: If it failed, it means TCC (macOS security) is blocking us.
            // We must show an alert and open System Settings for the user.
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Permiso Requerido / Permission Required"
                alert.informativeText = "Detalle del error: \(errorDesc)\n\nRightClick+ necesita 'Acceso total al disco' (Full Disk Access) para crear archivos.\n\nPor favor, haz clic en 'Abrir Configuración' (Open Settings), enciende el interruptor de RightClick+ y vuelve a intentarlo."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Open Settings / Abrir Configuración")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
