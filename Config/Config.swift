import SwiftUI


let base = "api.nodesya.website" // im crying

enum AppConfig {
    static let apiBaseURL = "https://\(base)"
    static let wsBaseURL = "wss://\(base)"
    static let globalBackgroundColor = Color(hex: 0x17131B)
    static let globalBackgroundColorLight = Color(hex: 0x201B26)
    static let globalBackgroundColorLighter = Color(hex: 0x2C2433)
    static let nodesGreen = Color(hex: 0x008E56)
    static let nodesPurple = Color(hex: 0x38057D)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
