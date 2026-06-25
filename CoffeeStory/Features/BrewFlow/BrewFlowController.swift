import SwiftUI
import SwiftData

// MARK: - 全局路由（管理冲煮流程覆盖层）
@MainActor
@Observable
final class AppRouter {
    var presentedSession: ActiveBrewSession?
    var showPaywall = false

    private func defaultRatio() -> Double {
        let r = UserDefaults.standard.double(forKey: SettingsKey.defaultRatio)
        return r > 0 ? r : 16
    }
    private func defaultTemplate() -> PourTemplate {
        PourTemplate(rawValue: UserDefaults.standard.string(forKey: SettingsKey.defaultTemplate) ?? "") ?? .three
    }
    /// 无历史参数时，按烘焙度给出更合理的默认水温
    private func defaultTemp(for roast: RoastLevel) -> Double {
        switch roast {
        case .extraLight:  96
        case .light:       95
        case .mediumLight: 93
        case .medium:      91
        case .mediumDark:  89
        case .dark:        87
        }
    }

    /// 开始一次新的冲煮（按 I-04 规则预填）。免费版每包至多 N 次。
    func startBrew(for bean: Bean, context: ModelContext, isPro: Bool = true) {
        if !isPro && bean.brewCount >= FreeLimits.maxBrewsPerBean {
            showPaywall = true
            return
        }
        // 清除任何遗留草稿
        if let existing = try? context.fetch(FetchDescriptor<ActiveBrewSession>()) {
            existing.forEach { context.delete($0) }
        }
        let session = ActiveBrewSession(beanID: bean.id)

        let prefill: Brew?
        if bean.status == .dialedIn, let best = bean.bestBrew {
            prefill = best
        } else {
            prefill = bean.latestBrew
        }

        session.grind = prefill?.grind ?? 20
        session.dose = prefill?.dose ?? 15
        let ratio = prefill.map { $0.ratio } ?? defaultRatio()
        session.water = prefill?.water ?? (session.dose * ratio).rounded()
        session.temp = prefill?.temp ?? defaultTemp(for: bean.roastLevel)
        if let pours = prefill?.pours, !pours.isEmpty {
            let scaled = BrewFlowController.rescaledPours(pours, toWater: session.water)
            session.pours = BrewFlowController.normalizedPours(scaled, fallbackWater: session.water, preserveLabels: true)
        } else {
            session.pours = defaultTemplate().stages(dose: session.dose, water: session.water)
        }
        session.phase = .prepare

        context.insert(session)
        presentedSession = session
    }

    func resume(_ session: ActiveBrewSession) {
        presentedSession = session
    }
}

// MARK: - 冲煮流程控制器
@MainActor
@Observable
final class BrewFlowController {
    let session: ActiveBrewSession
    let bean: Bean
    let context: ModelContext
    var ratio: Double
    var didGraduate = false

    init(session: ActiveBrewSession, bean: Bean, context: ModelContext) {
        self.session = session
        self.bean = bean
        self.context = context
        self.ratio = session.ratio > 0 ? session.ratio : 16
    }

    var attemptNumber: Int { bean.brewCount + 1 }

    static func rescaledPours(_ pours: [PourStage], toWater water: Double) -> [PourStage] {
        guard !pours.isEmpty else { return pours }
        let oldTotal = pours.last?.targetWaterCumulative ?? water
        guard oldTotal > 0 else { return pours }
        let factor = water / oldTotal
        return pours.map { stage in
            var copy = stage
            copy.targetWaterCumulative = (stage.targetWaterCumulative * factor).rounded()
            return copy
        }
    }

    static func normalizedPours(_ input: [PourStage], fallbackWater: Double, preserveLabels: Bool) -> [PourStage] {
        var source = input.isEmpty
            ? [PourStage(label: "注水", targetWaterCumulative: fallbackWater, targetTime: 150)]
            : migrateLegacyStartTimes(input)

        var previousWater = 0.0
        var previousTime: TimeInterval = 0
        for idx in source.indices {
            var stage = source[idx]
            if !preserveLabels {
                let label = stage.label.trimmingCharacters(in: .whitespacesAndNewlines)
                stage.label = label.isEmpty ? "阶段 \(idx + 1)" : label
            }

            let water = stage.targetWaterCumulative.clampedTo(1...3000).rounded()
            stage.targetWaterCumulative = max(previousWater, water)
            previousWater = stage.targetWaterCumulative

            let planned = stage.targetTime ?? previousTime + defaultDuration(for: idx)
            stage.targetTime = max(previousTime + 5, planned.clampedTo(5...7200).rounded())
            previousTime = stage.targetTime ?? previousTime
            source[idx] = stage
        }
        return source
    }

    private static func defaultDuration(for index: Int) -> TimeInterval {
        index == 0 ? 30 : 60
    }

    private static func migrateLegacyStartTimes(_ stages: [PourStage]) -> [PourStage] {
        guard stages.count > 1,
              let first = stages.first?.targetTime,
              abs(first) < 0.5 else { return stages }
        var migrated = stages
        for idx in migrated.indices {
            if let next = stages[safe: idx + 1]?.targetTime {
                migrated[idx].targetTime = next
            } else {
                let current = stages[idx].targetTime ?? 0
                let previous = idx > 0 ? (stages[idx - 1].targetTime ?? current) : current
                migrated[idx].targetTime = current + max(60, current - previous)
            }
        }
        return migrated
    }

    // MARK: 准备：粉水比三元联动
    func setDose(_ d: Double) {
        session.dose = d.clampedTo(1...200)
        session.water = (session.dose * ratio).rounded()
        rescaleTemplateWater()
    }
    func setWater(_ w: Double) {
        session.water = w.clampedTo(1...3000)
        if session.dose > 0 { ratio = session.water / session.dose }
        rescaleTemplateWater()
    }
    func setRatio(_ r: Double) {
        ratio = r
        session.water = (session.dose * ratio).rounded()
        rescaleTemplateWater()
    }
    func applyTemplate(_ t: PourTemplate) {
        session.pours = t.stages(dose: session.dose, water: session.water)
        session.currentStageIndex = 0
    }
    func setCustomPours(_ pours: [PourStage], syncWater: Bool = true) {
        session.pours = Self.normalizedPours(pours, fallbackWater: session.water, preserveLabels: true)
        session.currentStageIndex = min(session.currentStageIndex, max(0, session.pours.count - 1))
        guard syncWater, let total = session.pours.last?.targetWaterCumulative else { return }
        session.water = total.clampedTo(1...3000)
        if session.dose > 0 { ratio = session.water / session.dose }
    }
    private func finalizePours() {
        session.pours = Self.normalizedPours(session.pours, fallbackWater: session.water, preserveLabels: false)
        session.currentStageIndex = min(session.currentStageIndex, max(0, session.pours.count - 1))
        if let total = session.pours.last?.targetWaterCumulative {
            session.water = total.clampedTo(1...3000)
            if session.dose > 0 { ratio = session.water / session.dose }
        }
    }
    private func rescaleTemplateWater() {
        // 末段累计水量跟随总水量同步
        guard !session.pours.isEmpty else { return }
        let oldTotal = session.pours.last?.targetWaterCumulative ?? session.water
        guard oldTotal > 0 else { return }
        let factor = session.water / oldTotal
        guard abs(factor - 1) > 0.001 else { return }
        session.pours = session.pours.map { stage in
            var s = stage
            s.targetWaterCumulative = (stage.targetWaterCumulative * factor).rounded()
            return s
        }
    }

    // MARK: 计时
    func startTimer() {
        finalizePours()
        session.startedAt = Date()
        session.isPaused = false
        session.accumulatedPaused = 0
        session.currentStageIndex = 0
        session.phase = .brewing
        Haptics.impact(.medium)
    }
    var isRunning: Bool { session.startedAt != nil && !session.isPaused }

    func togglePause() {
        let now = Date()
        if session.isPaused {
            if let last = session.lastPausedAt {
                session.accumulatedPaused += now.timeIntervalSince(last)
            }
            session.isPaused = false
            session.lastPausedAt = nil
        } else {
            session.isPaused = true
            session.lastPausedAt = now
        }
        Haptics.selection()
    }

    func nextStage() {
        guard session.startedAt != nil else { return }
        let e = session.elapsed()
        guard session.currentStageIndex < session.pours.count else { return }
        session.pours[session.currentStageIndex].actualAt = e
        if session.currentStageIndex < session.pours.count - 1 {
            session.currentStageIndex += 1
        }
        Haptics.impact(.light)
    }

    func undoStage() {
        if session.currentStageIndex > 0 {
            session.currentStageIndex -= 1
            session.pours[session.currentStageIndex].actualAt = nil
        } else if !session.pours.isEmpty, session.pours[0].actualAt != nil {
            session.pours[0].actualAt = nil
        }
        Haptics.selection()
    }

    func finishBrewing() {
        session.capturedTotalTime = session.elapsed()
        if session.currentStageIndex < session.pours.count,
           session.pours[session.currentStageIndex].actualAt == nil {
            session.pours[session.currentStageIndex].actualAt = session.capturedTotalTime
        }
        session.phase = .review
        Haptics.impact(.medium)
    }

    // 注水进度（已完成累计 / 计划总量）
    var waterProgress: Double {
        guard let total = session.pours.last?.targetWaterCumulative, total > 0 else { return 0 }
        let completed = session.pours
            .filter { $0.actualAt != nil }
            .map(\.targetWaterCumulative)
            .max() ?? 0
        return min(1, completed / total)
    }

    // MARK: 保存 / 放弃
    @discardableResult
    func save() -> Bool {
        let brew = Brew(grind: session.grind, dose: session.dose, water: session.water, temp: session.temp)
        brew.totalTime = session.capturedTotalTime
        brew.pours = session.pours
        brew.acidity = session.acidity
        brew.sweetness = session.sweetness
        brew.bodyScore = session.bodyScore
        brew.aftertaste = session.aftertaste
        brew.balance = session.balance
        brew.overall = session.overall
        brew.takeaway = session.takeaway
        brew.nextTweaks = session.nextTweaks
        brew.nextTweakNote = session.nextTweakNote

        context.insert(brew)
        brew.bean = bean

        if session.markBest {
            for b in bean.brews { b.isBest = false }
            brew.isBest = true
        }

        bean.remainingGrams = max(0, bean.remainingGrams - brew.dose)

        context.delete(session)
        Haptics.success()
        didGraduate = bean.remainingGrams <= 0
        return didGraduate
    }

    func discard() {
        context.delete(session)
    }

    func graduateBean() {
        if let best = bean.bestBrew {
            let r = RecipeArchive()
            r.sourceBeanName = bean.name
            r.originText = bean.originText
            r.processRaw = bean.process.rawValue
            r.roastLevelRaw = bean.roastLevel.rawValue
            r.flavorTags = bean.flavorTags
            r.grind = best.grind
            r.dose = best.dose
            r.water = best.water
            r.temp = best.temp
            r.totalTime = best.totalTime
            r.pours = best.pours
            r.overall = best.overall
            r.takeaway = best.takeaway
            context.insert(r)
        }
        bean.archived = true
        bean.archivedAt = Date()
    }
}
