import CoreText
import SwiftUI

enum FallowFont {
    /// Family name reported by the bundled Cult VP file.
    static let name = "Cult VP"

    static func register() {
        guard let url = Bundle.main.url(forResource: "CultVP-Branding", withExtension: "otf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func brand(_ size: CGFloat) -> Font {
        .custom(name, size: size)
    }
}

enum FallowType {
    static func brand(_ size: CGFloat) -> Font { FallowFont.brand(size) }
    static let screenTitle = Font.system(size: 25, weight: .semibold)
    static let heading = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let secondary = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)
    static let button = Font.system(size: 17, weight: .semibold)
    static let quietButton = Font.system(size: 16, weight: .regular)
    static let process = Font.system(size: 16, weight: .regular, design: .monospaced)
    static let macProcess = Font.system(size: 15, weight: .regular, design: .monospaced)
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static let eyebrow = Font.system(size: 12, weight: .medium)
}

/// Small tracked capitals under a display title.
struct Eyebrow: View {
    var text: String
    var color: Color = Theme.mute

    var body: some View {
        Text(text.uppercased())
            .font(FallowType.eyebrow)
            .tracking(2.4)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }
}

struct FallowWordmark: View {
    var size: CGFloat = 32

    var body: some View {
        Text("FALLOW")
            .font(FallowType.brand(size))
            .tracking(size * 0.12)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
    }
}
