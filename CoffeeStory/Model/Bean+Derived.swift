import Foundation

extension Bean {
    /// 按时间升序的冲煮列表
    var orderedBrews: [Brew] {
        brews.sorted { $0.createdAt < $1.createdAt }
    }

    var brewCount: Int { brews.count }

    var bestBrew: Brew? { brews.first { $0.isBest } }

    /// 最近一次冲煮
    var latestBrew: Brew? { orderedBrews.last }

    var status: BeanStatus {
        if archived { return .archived }
        if brews.isEmpty { return .fresh }
        if bestBrew != nil { return .dialedIn }
        return .dialing
    }

    /// 养豆天数（无烘焙日期返回 nil）
    var restDays: Int? {
        guard let roastDate else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: roastDate)
        let now = cal.startOfDay(for: Date())
        return cal.dateComponents([.day], from: start, to: now).day
    }

    var tasteStatus: TasteStatus {
        guard let days = restDays else { return .unknown }
        let w = roastLevel.window
        if days < w.peakStart { return .resting }
        if days <= w.peakEnd { return .peak }
        if days <= w.staleAfter { return .fading }
        return .past
    }

    /// 0...1 已消耗比例
    var consumedProgress: Double {
        guard bagWeightGrams > 0 else { return 0 }
        let consumed = bagWeightGrams - remainingGrams
        return min(1, max(0, consumed / bagWeightGrams))
    }

    /// 还能冲约几杯（按最近一次或默认 15g 粉量估算）
    func estimatedCupsLeft(defaultDose: Double = 15) -> Int {
        let dose = latestBrew?.dose ?? defaultDose
        guard dose > 0 else { return 0 }
        return Int((remainingGrams / dose).rounded(.down))
    }

    var bestScore: Double? { bestBrew?.overall }

    /// 距上次冲煮天数（无冲煮返回 nil）
    var daysSinceLastBrew: Int? {
        guard let last = latestBrew else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: last.createdAt),
                                  to: cal.startOfDay(for: Date())).day
    }

    /// "该冲了" 排序评分（越高越靠前）
    var shouldBrewScore: Double {
        // 赏味贴合度
        let fit: Double
        switch tasteStatus {
        case .peak:    fit = 1.0
        case .resting: fit = 0.5
        case .fading:  fit = 0.4
        case .past:    fit = 0.2
        case .unknown: fit = 0.4
        }
        // 久未冲
        let idle = min(Double(daysSinceLastBrew ?? 7) / 7.0, 1.0)
        // 状态加成
        let bonus: Double
        switch status {
        case .fresh:    bonus = 0.5
        case .dialing:  bonus = 0.3
        case .dialedIn: bonus = 0.1
        case .archived: bonus = 0.0
        }
        return 0.5 * fit + 0.3 * idle + 0.2 * bonus
    }
}
