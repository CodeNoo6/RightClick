import Foundation

enum LicensePlan: String, Codable {
    case monthly, annual, lifetime
}

private struct LicenseData: Codable {
    var key: String
    var plan: LicensePlan
    var expiresAt: Date?
}

class LicenseManager {
    static let shared = LicenseManager()
    static let licenseUpdatedNotification = Notification.Name("RightClickLicenseUpdated")

    private let validateURL = URL(string: "https://www.rightclickmac.com/api/check.php")!

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "653RS235MN.gimomagic.RightClick")
    }

    private var licenseFileURL: URL? {
        containerURL?.appendingPathComponent("license.json")
    }

    private var machineID: String {
        let matching = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        defer { IOObjectRelease(platformExpert) }
        guard let serialNumber = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? String else {
            return "unknown-machine"
        }
        return serialNumber
    }

    private init() {}

    // MARK: - Read

    private func loadData() -> LicenseData? {
        guard let url = licenseFileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LicenseData.self, from: data)
    }

    var isPro: Bool {
        guard let data = loadData() else { return false }
        if let expiry = data.expiresAt {
            return expiry > Date()
        }
        return true
    }

    var plan: LicensePlan? {
        loadData()?.plan
    }

    func revalidate() {
        guard let key = loadData()?.key else { return }
        activate(key: key) { _, _ in }
    }

    var expiresAt: Date? {
        loadData()?.expiresAt
    }

    var daysRemaining: Int? {
        guard let expiry = expiresAt else { return nil }
        let diff = expiry.timeIntervalSinceNow
        return diff > 0 ? Int(floor(diff / 86400.0)) : 0
    }

    // MARK: - Activate

    func activate(key: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidFormat(trimmed) else {
            completion(false, NSLocalizedString("license.invalid_format", comment: ""))
            return
        }
        validateWithServer(trimmed, completion: completion)
    }

    func deactivate() {
        if let url = licenseFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private

    private func isValidFormat(_ key: String) -> Bool {
        let pattern = "^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private func save(_ data: LicenseData) {
        guard let url = licenseFileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: url, options: .atomic)
        }
    }

    private func validateWithServer(_ key: String, completion: @escaping (Bool, String) -> Void) {
        var req = URLRequest(url: validateURL, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("RightClickPlus/1.0", forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = ["key": key, "machine_id": machineID]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("--- SERVER RESPONSE ---")
                print(responseString)
                print("-----------------------")
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("HTTP Error: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(false, "Server Error (\(httpResponse.statusCode))")
                }
                return
            }

            if error != nil {
                let alreadyActivated = self.loadData()?.key == key && self.isPro
                DispatchQueue.main.async {
                    completion(alreadyActivated,
                               NSLocalizedString(alreadyActivated ? "license.activated" : "license.invalid_key", comment: ""))
                }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool else {
                DispatchQueue.main.async {
                    completion(false, NSLocalizedString("license.invalid_key", comment: ""))
                }
                return
            }

            DispatchQueue.main.async {
                if valid {
                    let planRaw = json["plan"] as? String ?? "lifetime"
                    let plan = LicensePlan(rawValue: planRaw) ?? .lifetime
                    var expiresAt: Date? = nil

                    if let expiresStr = json["expires_at"] as? String {
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        fmt.timeZone = TimeZone(identifier: "UTC")
                        expiresAt = fmt.date(from: expiresStr)
                    }

                    let licenseData = LicenseData(key: key, plan: plan, expiresAt: expiresAt)
                    self.save(licenseData)
                    NotificationCenter.default.post(name: LicenseManager.licenseUpdatedNotification, object: nil)

                    let message = self.activationMessage(plan: plan)
                    completion(true, message)
                } else {
                    let errorKey = json["error"] as? String ?? ""
                    let msgKey: String
                    switch errorKey {
                    case "expired": msgKey = "license.expired"
                    case "already_used": msgKey = "license.already_used"
                    default: msgKey = "license.invalid_key"
                    }
                    completion(false, NSLocalizedString(msgKey, comment: ""))
                }
            }
        }.resume()
    }

    private func activationMessage(plan: LicensePlan) -> String {
        switch plan {
        case .monthly:
            let days = daysRemaining ?? 30
            return String(format: NSLocalizedString("license.activated_monthly", comment: ""), days)
        case .annual:
            let days = daysRemaining ?? 365
            return String(format: NSLocalizedString("license.activated_annual", comment: ""), days)
        case .lifetime:
            return NSLocalizedString("license.activated", comment: "")
        }
    }
}
