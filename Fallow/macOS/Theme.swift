import SwiftUI

enum Theme {
    static let canvas = Color(hex: 0xF4F1EA)
    static let ink = Color(hex: 0x242421)
    static let mute = Color(hex: 0x5C5A54)
    static let ash = Color(hex: 0x8A877F)
    static let paper = Color(hex: 0xEDE8DE)
    static let wash = Color(hex: 0xEDE8DE)
    static let shell = Color(hex: 0xE7E4DE)
    static let rim = Color(hex: 0xD9D5CC)
    static let light = Color(hex: 0xFFF4D6)
    static let lightHot = Color(hex: 0xE2C38B)
    static let glow = Color(hex: 0xE2C38B)
    static let field = Color(hex: 0xF4F1EA)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
