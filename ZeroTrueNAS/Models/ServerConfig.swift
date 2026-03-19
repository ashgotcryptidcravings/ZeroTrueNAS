import Foundation

struct ServerConfig {
    static let defaultAddress = "192.168.0.107"
    static let defaultHostname = "truenas.local"
    static let defaultBasePath = "/mnt"

    private static let addressKey = "server_address"

    static var savedAddress: String {
        get {
            UserDefaults.standard.string(forKey: addressKey) ?? defaultAddress
        }
        set {
            UserDefaults.standard.set(newValue, forKey: addressKey)
        }
    }

    static var baseURL: String {
        "http://\(savedAddress)/api/v2.0"
    }
}
