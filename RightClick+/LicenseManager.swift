import Foundation

class LicenseManager {
    static let shared = LicenseManager()

    private let defaults = UserDefaults(suiteName: "653RS235MN.gimomagic.RightClick") ?? .standard
    private let keyStorageKey = "proLicenseKey"
    private let proStatusKey  = "isProActivated"

    private init() {}

    var isPro: Bool {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick"),
           let content = try? String(contentsOf: container.appendingPathComponent("license.txt"), encoding: .utf8),
           content.trimmingCharacters(in: .whitespacesAndNewlines) == "pro" {
            return true
        }
        return defaults.bool(forKey: proStatusKey)
    }

    func activate(key: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidFormat(trimmed) else {
            completion(false, NSLocalizedString("license.invalid_format", comment: ""))
            return
        }

        // TODO: replace with real Bold API validation when available
        // For now: accept any key matching XXXX-XXXX-XXXX-XXXX
        validateWithServer(trimmed, completion: completion)
    }

    func deactivate() {
        defaults.removeObject(forKey: keyStorageKey)
        defaults.set(false, forKey: proStatusKey)
    }

    private func isValidFormat(_ key: String) -> Bool {
        let pattern = "^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateWithServer(_ key: String, completion: @escaping (Bool, String) -> Void) {
        // --- Bold API integration point ---
        // When Bold is ready, replace this block with:
        //
        // let url = URL(string: "https://api.bold.co/v1/licenses/validate")!
        // var req = URLRequest(url: url)
        // req.httpMethod = "POST"
        // req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // req.httpBody = try? JSONEncoder().encode(["key": key, "product": "rightclickplus"])
        // URLSession.shared.dataTask(with: req) { data, _, _ in
        //     let valid = (try? JSONDecoder().decode([String:Bool].self, from: data ?? Data()))?["valid"] ?? false
        //     DispatchQueue.main.async {
        //         if valid {
        //             self.defaults.set(key, forKey: self.keyStorageKey)
        //             self.defaults.set(true, forKey: self.proStatusKey)
        //         }
        //         completion(valid, valid ? NSLocalizedString("license.activated", comment: "") : NSLocalizedString("license.invalid_key", comment: ""))
        //     }
        // }.resume()

        // Stub: accept any valid-format key
        DispatchQueue.main.async {
            self.defaults.set(key, forKey: self.keyStorageKey)
            self.defaults.set(true, forKey: self.proStatusKey)
            self.defaults.synchronize()
            // Write a flag file so the extension can read it without UserDefaults cache issues
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick") {
                try? "pro".write(to: container.appendingPathComponent("license.txt"), atomically: true, encoding: .utf8)
            }
            completion(true, NSLocalizedString("license.activated", comment: ""))
        }
    }
}
