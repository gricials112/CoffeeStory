import SwiftUI
import UIKit

// MARK: - 触感反馈
enum Haptics {
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true
    }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - 设置键
enum SettingsKey {
    static let defaultRatio = "settings.defaultRatio"
    static let keepScreenOn = "settings.keepScreenOn"
    static let haptics = "settings.haptics"
    static let defaultTemplate = "settings.defaultTemplate"
    static let pourCumulative = "settings.pourCumulative"
    static let hasOnboarded = "settings.hasOnboarded"
    static let colorScheme = "settings.colorScheme"

    // 分享卡片显示选项
    static let shareShowFlavorTags = "share.showFlavorTags"
    static let shareShowSubScores  = "share.showSubScores"
    static let shareShowGrinder    = "share.showGrinder"
    static let shareShowRoastInfo  = "share.showRoastInfo"
}

// MARK: - 注水模板
enum PourTemplate: String, CaseIterable, Identifiable {
    case single, bloomSingle, three, four
    var id: String { rawValue }
    var label: String {
        switch self {
        case .single:      "单段"
        case .bloomSingle: "闷蒸+单段"
        case .three:       "三段"
        case .four:        "四段"
        }
    }

    /// 依粉量/水量生成分段（累计目标水量）
    func stages(dose: Double, water: Double) -> [PourStage] {
        let bloom = min((2 * dose).rounded(), water)
        switch self {
        case .single:
            return [PourStage(label: "注水", targetWaterCumulative: water, targetTime: nil)]
        case .bloomSingle:
            return [
                PourStage(label: "闷蒸", targetWaterCumulative: bloom, targetTime: 0),
                PourStage(label: "注水", targetWaterCumulative: water, targetTime: 30)
            ]
        case .three:
            return [
                PourStage(label: "闷蒸",  targetWaterCumulative: bloom, targetTime: 0),
                PourStage(label: "注水 1", targetWaterCumulative: (water * 0.625).rounded(), targetTime: 30),
                PourStage(label: "注水 2", targetWaterCumulative: water, targetTime: 75)
            ]
        case .four:
            return [
                PourStage(label: "闷蒸",  targetWaterCumulative: bloom, targetTime: 0),
                PourStage(label: "注水 1", targetWaterCumulative: (water * 0.5).rounded(), targetTime: 30),
                PourStage(label: "注水 2", targetWaterCumulative: (water * 0.75).rounded(), targetTime: 60),
                PourStage(label: "注水 3", targetWaterCumulative: water, targetTime: 90)
            ]
        }
    }
}

// MARK: - 相似配方匹配
enum RecipeMatch {
    private static func roastIndex(_ r: RoastLevel) -> Int {
        switch r {
        case .light: 0; case .mediumLight: 1; case .medium: 2; case .mediumDark: 3; case .dark: 4
        }
    }
    private static func originToken(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .split(separator: " ").first.map(String.init) ?? ""
    }

    static func similarity(bean: Bean, recipe: RecipeArchive) -> Double {
        var s = 0.0
        if bean.process == recipe.process { s += 0.5 }
        let bt = originToken(bean.originText), rt = originToken(recipe.originText)
        if !bt.isEmpty, bt == rt { s += 0.3 }
        let diff = abs(roastIndex(bean.roastLevel) - roastIndex(recipe.roastLevel))
        s += 0.2 * (1 - Double(diff) / 4)
        return s
    }

    static func bestMatch(for bean: Bean, in recipes: [RecipeArchive]) -> RecipeArchive? {
        var best: RecipeArchive?
        var bestScore = 0.6
        for recipe in recipes {
            let s = similarity(bean: bean, recipe: recipe)
            if s >= bestScore {
                if s > bestScore || (best.map { recipe.createdAt > $0.createdAt } ?? true) {
                    best = recipe
                    bestScore = s
                }
            }
        }
        return best
    }
}

// MARK: - 防熄屏
private struct KeepAwakeModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .onChange(of: active, initial: true) { _, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {
    func keepAwake(_ active: Bool) -> some View { modifier(KeepAwakeModifier(active: active)) }
}
