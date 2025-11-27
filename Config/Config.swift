import Foundation


let base = "wanting-apps-executive-uncle.trycloudflare.com"

enum AppConfig {
    static let apiBaseURL = "https://\(base)"
    static let wsBaseURL = "wss://\(base)"
}
