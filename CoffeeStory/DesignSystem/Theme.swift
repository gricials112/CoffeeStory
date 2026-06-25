import SwiftUI

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 20
    static let field: CGFloat = 14
    static let chip: CGFloat = 10
}

// MARK: - 实体内容卡片（非玻璃）
struct SurfaceCard: ViewModifier {
    var padding: CGFloat = Space.lg
    var tint: Color = DT.surface
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(tint, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(DT.hairline, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
    }
}

extension View {
    func surfaceCard(padding: CGFloat = Space.lg, tint: Color = DT.surface) -> some View {
        modifier(SurfaceCard(padding: padding, tint: tint))
    }
}

// MARK: - 字体助手
extension Font {
    /// 等宽圆体数值（防跳动）
    static func roundedNumber(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: - 时间格式化
enum TimeFmt {
    static func mmss(_ t: TimeInterval) -> String {
        let total = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func parse(_ text: String) -> TimeInterval? {
        let cleaned = text
            .replacingOccurrences(of: "：", with: ":")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]),
                  seconds >= 0, seconds < 60 else { return nil }
            return minutes * 60 + seconds
        }
        return Double(cleaned)
    }
}

// MARK: - 数值格式化
enum NumFmt {
    static func g(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
    static func ratio(_ r: Double) -> String {
        guard r > 0 else { return "—" }
        return "1:" + String(format: "%.1f", r)
    }
    static func score(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
