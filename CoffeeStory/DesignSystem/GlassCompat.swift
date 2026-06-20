import SwiftUI

// Liquid Glass (iOS 26+) 兼容封装：在 iOS 26 及以上使用玻璃材质，
// 在更低版本（iOS 18+）回退到系统标准按钮样式与普通容器，保证向下兼容。

extension View {
    /// 对应 `.buttonStyle(.glass)`，低版本回退为 `.bordered`。
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// 对应 `.buttonStyle(.glassProminent)`，低版本回退为 `.borderedProminent`。
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

/// 对应 `GlassEffectContainer`，低版本直接渲染内容。
struct GlassContainer<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
