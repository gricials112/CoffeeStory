import Foundation
import SwiftData

// MARK: - 一包豆子（调参项目）
@Model
final class Bean {
    var id: UUID = UUID()
    var name: String = ""
    var roaster: String = ""
    var originText: String = ""
    var process: Process = Process.washed
    var roastLevel: RoastLevel = RoastLevel.mediumLight
    var roastDate: Date?
    var bagWeightGrams: Double = 200
    var remainingGrams: Double = 200
    var flavorTags: [String] = []
    @Attribute(.externalStorage) var coverImageData: Data?
    var notes: String = ""
    var grinderNote: String = ""
    var createdAt: Date = Date()
    var archived: Bool = false
    var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Brew.bean)
    var brews: [Brew] = []

    init(name: String = "", bagWeightGrams: Double = 200) {
        self.id = UUID()
        self.name = name
        self.bagWeightGrams = bagWeightGrams
        self.remainingGrams = bagWeightGrams
        self.createdAt = Date()
    }
}

// MARK: - 一次冲煮（实验迭代）
@Model
final class Brew {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var grind: Double = 20
    var dose: Double = 15
    var water: Double = 240
    var temp: Double?
    var totalTime: TimeInterval = 0
    var pours: [PourStage] = []

    // 风味（可空，0–5，0.5 步进）
    var acidity: Double?
    var sweetness: Double?
    var bodyScore: Double?
    var aftertaste: Double?
    var balance: Double?
    var overall: Double?

    var takeaway: String = ""
    var nextTweaks: [NextTweak] = []
    var nextTweakNote: String = ""
    var isBest: Bool = false

    var bean: Bean?

    init(grind: Double = 20, dose: Double = 15, water: Double = 240, temp: Double? = 92) {
        self.id = UUID()
        self.createdAt = Date()
        self.grind = grind
        self.dose = dose
        self.water = water
        self.temp = temp
    }

    var ratio: Double { dose > 0 ? water / dose : 0 }

    func score(for dim: FlavorDimension) -> Double? {
        switch dim {
        case .acidity:    acidity
        case .sweetness:  sweetness
        case .body:       bodyScore
        case .aftertaste: aftertaste
        case .balance:    balance
        }
    }

    var hasAnyScore: Bool {
        overall != nil || acidity != nil || sweetness != nil
            || bodyScore != nil || aftertaste != nil || balance != nil
    }
}

// MARK: - 进行中的冲煮草稿（持久化，至多一条，用于崩溃/退出恢复）
@Model
final class ActiveBrewSession {
    var id: UUID = UUID()
    var beanID: UUID = UUID()
    var phaseRaw: String = BrewPhase.prepare.rawValue

    var grind: Double = 20
    var dose: Double = 15
    var water: Double = 240
    var temp: Double?
    var pours: [PourStage] = []
    var currentStageIndex: Int = 0

    // 计时（墙钟）
    var startedAt: Date?
    var accumulatedPaused: TimeInterval = 0
    var isPaused: Bool = false
    var lastPausedAt: Date?
    var capturedTotalTime: TimeInterval = 0

    // 复盘草稿
    var acidity: Double?
    var sweetness: Double?
    var bodyScore: Double?
    var aftertaste: Double?
    var balance: Double?
    var overall: Double?
    var takeaway: String = ""
    var nextTweaks: [NextTweak] = []
    var nextTweakNote: String = ""
    var markBest: Bool = false

    var createdAt: Date = Date()

    init(beanID: UUID) {
        self.id = UUID()
        self.beanID = beanID
        self.createdAt = Date()
    }

    var phase: BrewPhase {
        get { BrewPhase(rawValue: phaseRaw) ?? .prepare }
        set { phaseRaw = newValue.rawValue }
    }

    var ratio: Double { dose > 0 ? water / dose : 0 }

    /// 当前已用时（基于墙钟，暂停时冻结）
    func elapsed(at now: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        var paused = accumulatedPaused
        if isPaused, let lastPausedAt {
            paused += now.timeIntervalSince(lastPausedAt)
        }
        return max(0, now.timeIntervalSince(startedAt) - paused)
    }
}

// MARK: - 配方库条目（独立快照，与豆子解耦）
@Model
final class RecipeArchive {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var sourceBeanName: String = ""
    var originText: String = ""
    var processRaw: String = Process.washed.rawValue
    var roastLevelRaw: String = RoastLevel.mediumLight.rawValue
    var flavorTags: [String] = []

    var grind: Double = 20
    var dose: Double = 15
    var water: Double = 240
    var temp: Double?
    var totalTime: TimeInterval = 0
    var pours: [PourStage] = []
    var overall: Double?
    var takeaway: String = ""

    init() {
        self.id = UUID()
        self.createdAt = Date()
    }

    var process: Process { Process(rawValue: processRaw) ?? .other }
    var roastLevel: RoastLevel { RoastLevel(rawValue: roastLevelRaw) ?? .medium }
    var ratio: Double { dose > 0 ? water / dose : 0 }
}
