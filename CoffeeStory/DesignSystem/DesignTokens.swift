import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

private func dyn(_ light: UInt, _ dark: UInt, _ alpha: CGFloat = 1) -> Color {
    Color(uiColor: UIColor { trait in
        let hex = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
    })
}

/// 语义设计令牌（Design Tokens）。UI 只引用此处，不写裸 hex。
enum DT {
    // 背景层
    static let canvas        = dyn(0xF5EFE4, 0x16110D)
    static let surface       = dyn(0xFFFDF7, 0x221A13)
    static let surfaceSunken = dyn(0xEEE6D7, 0x1B140E)

    // 文字层
    static let ink          = dyn(0x2A1C12, 0xF3E9DB)
    static let inkSecondary = dyn(0x6E5B49, 0xC3B2A0)
    static let inkTertiary  = dyn(0x9C8973, 0x8C7A67)

    // 品牌 / 强调
    static let coffee    = dyn(0x6F4E37, 0xA77A56)
    static let amber     = dyn(0xC2761B, 0xE29A3D)
    static let amberSoft = dyn(0xEAD7BE, 0x3A2A1B)
    static let gold      = dyn(0xB8860B, 0xE0BC52)
    static let goldSoft  = dyn(0xF1E4C0, 0x3D3115)

    // 状态色
    static let resting = dyn(0x3F7E78, 0x5FA39C)
    static let peak    = dyn(0x5E8C4A, 0x83B86A)
    static let fading  = dyn(0xB07A2A, 0xC59A4A)
    static let past    = dyn(0x9A8A77, 0x7C6E5E)

    // 风味色
    static let acidity    = dyn(0xA9B83E, 0xC2D157)
    static let sweet      = dyn(0xD2952F, 0xE8AE4C)
    static let bodyFlavor = dyn(0x8A5A33, 0xB4814E)
    static let after      = dyn(0x8A6D5B, 0xA98B76)
    static let balance    = dyn(0x6F8A66, 0x90A985)

    // 细节
    static let hairline = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(white: 0, alpha: 0.08)
    })
}
