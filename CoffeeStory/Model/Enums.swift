import SwiftUI

// MARK: - 处理法
enum Process: String, Codable, CaseIterable, Identifiable {
    case washed, natural, honey, anaerobic, wetHull, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .washed:    "水洗"
        case .natural:   "日晒"
        case .honey:     "蜜处理"
        case .anaerobic: "厌氧"
        case .wetHull:   "湿刨"
        case .other:     "其它"
        }
    }
}

// MARK: - 烘焙度
struct RoastWindow {
    let peakStart: Int
    let peakEnd: Int
    let staleAfter: Int
}

enum RoastLevel: String, Codable, CaseIterable, Identifiable {
    case extraLight, light, mediumLight, medium, mediumDark, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .extraLight:  "极浅"
        case .light:       "浅烘"
        case .mediumLight: "中浅"
        case .medium:      "中烘"
        case .mediumDark:  "中深"
        case .dark:        "深烘"
        }
    }
    var window: RoastWindow {
        switch self {
        case .extraLight:  RoastWindow(peakStart: 8, peakEnd: 30, staleAfter: 38)
        case .light:       RoastWindow(peakStart: 7, peakEnd: 28, staleAfter: 35)
        case .mediumLight: RoastWindow(peakStart: 5, peakEnd: 24, staleAfter: 32)
        case .medium:      RoastWindow(peakStart: 4, peakEnd: 21, staleAfter: 30)
        case .mediumDark:  RoastWindow(peakStart: 3, peakEnd: 18, staleAfter: 28)
        case .dark:        RoastWindow(peakStart: 2, peakEnd: 14, staleAfter: 24)
        }
    }
}

// MARK: - 赏味状态
enum TasteStatus {
    case unknown, resting, peak, fading, past
    var label: String {
        switch self {
        case .unknown: "未记录烘焙日期"
        case .resting: "养豆中"
        case .peak:    "最佳赏味"
        case .fading:  "风味尾声"
        case .past:    "已过赏味"
        }
    }
    var color: Color {
        switch self {
        case .unknown: DT.inkTertiary
        case .resting: DT.resting
        case .peak:    DT.peak
        case .fading:  DT.fading
        case .past:    DT.past
        }
    }
}

// MARK: - 豆子状态机
enum BeanStatus {
    case fresh, dialing, dialedIn, archived
    var label: String {
        switch self {
        case .fresh:    "新豆"
        case .dialing:  "调试中"
        case .dialedIn: "已解锁"
        case .archived: "已喝完"
        }
    }
    var color: Color {
        switch self {
        case .fresh:    DT.inkTertiary
        case .dialing:  DT.amber
        case .dialedIn: DT.gold
        case .archived: DT.past
        }
    }
    var symbol: String {
        switch self {
        case .fresh:    "leaf"
        case .dialing:  "slider.horizontal.3"
        case .dialedIn: "star.fill"
        case .archived: "checkmark.seal"
        }
    }
}

// MARK: - 风味维度
enum FlavorDimension: String, CaseIterable, Identifiable {
    case acidity, sweetness, body, aftertaste, balance
    var id: String { rawValue }
    var label: String {
        switch self {
        case .acidity:    "酸"
        case .sweetness:  "甜"
        case .body:       "醇厚"
        case .aftertaste: "余韵"
        case .balance:    "平衡"
        }
    }
    var color: Color {
        switch self {
        case .acidity:    DT.acidity
        case .sweetness:  DT.sweet
        case .body:       DT.bodyFlavor
        case .aftertaste: DT.after
        case .balance:    DT.balance
        }
    }
}

// MARK: - 下次怎么调
enum TweakDimension: String, Codable, CaseIterable, Identifiable {
    case grind, temp, ratio, dose, pour
    var id: String { rawValue }
    var label: String {
        switch self {
        case .grind: "研磨"
        case .temp:  "水温"
        case .ratio: "粉水比"
        case .dose:  "粉量"
        case .pour:  "注水"
        }
    }
    var directions: [TweakDirection] {
        switch self {
        case .grind: [.finer, .coarser]
        case .temp:  [.up, .down]
        case .ratio: [.up, .down]
        case .dose:  [.more, .less]
        case .pour:  [.faster, .slower, .addStage, .removeStage]
        }
    }
}

enum TweakDirection: String, Codable, CaseIterable, Identifiable {
    case finer, coarser, up, down, more, less, faster, slower, addStage, removeStage
    var id: String { rawValue }
    var label: String {
        switch self {
        case .finer:       "更细"
        case .coarser:     "更粗"
        case .up:          "调高"
        case .down:        "调低"
        case .more:        "增加"
        case .less:        "减少"
        case .faster:      "更快"
        case .slower:      "更慢"
        case .addStage:    "多一段"
        case .removeStage: "少一段"
        }
    }
}

// MARK: - 注水段（值类型，随 Brew 持久化）
struct PourStage: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var targetWaterCumulative: Double
    /// 该阶段计划完成的累计时间（秒）。
    var targetTime: TimeInterval?
    var actualAt: TimeInterval?
}

// MARK: - 下次调整建议（值类型）
struct NextTweak: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var dimension: TweakDimension
    var direction: TweakDirection
    var label: String { "\(dimension.label)·\(direction.label)" }
}

// MARK: - 冲煮流程阶段
enum BrewPhase: String, Codable {
    case prepare, brewing, review
}
