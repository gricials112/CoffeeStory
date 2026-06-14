#if DEBUG
import Foundation
import SwiftData

/// 仅 DEBUG：当启动环境变量 SEED_SAMPLE=1 时注入演示数据，便于功能测试与截图。
enum SampleData {
    static func seedIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.environment["SEED_SAMPLE"] == "1" else { return }
        let existing = (try? context.fetch(FetchDescriptor<Bean>())) ?? []
        guard existing.isEmpty else { return }

        UserDefaults.standard.set(true, forKey: SettingsKey.hasOnboarded)

        func day(_ ago: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -ago, to: Date()) ?? Date()
        }

        func brew(_ bean: Bean, daysAgo: Int, grind: Double, dose: Double, water: Double,
                  temp: Double, time: TimeInterval, overall: Double?,
                  scores: (Double, Double, Double, Double, Double)? = nil,
                  takeaway: String, tweaks: [NextTweak] = [], best: Bool = false) {
            let b = Brew(grind: grind, dose: dose, water: water, temp: temp)
            b.createdAt = day(daysAgo)
            b.totalTime = time
            b.pours = PourTemplate.three.stages(dose: dose, water: water).enumerated().map { idx, p in
                var s = p
                s.actualAt = (p.targetTime ?? Double(idx) * 30) + 2
                return s
            }
            b.overall = overall
            if let sc = scores {
                b.acidity = sc.0; b.sweetness = sc.1; b.bodyScore = sc.2
                b.aftertaste = sc.3; b.balance = sc.4
            }
            b.takeaway = takeaway
            b.nextTweaks = tweaks
            b.isBest = best
            context.insert(b)
            b.bean = bean
        }

        // 1) 已解锁：埃塞耶加（收敛曲线）
        let yirga = Bean(name: "耶加雪菲 G1", bagWeightGrams: 200)
        yirga.originText = "埃塞俄比亚 耶加"
        yirga.process = .washed
        yirga.roastLevel = .light
        yirga.roastDate = day(12)
        yirga.flavorTags = ["柑橘", "茉莉", "红茶"]
        yirga.grinderNote = "C40 · 24格"
        yirga.remainingGrams = 138
        context.insert(yirga)
        brew(yirga, daysAgo: 9, grind: 24, dose: 15, water: 240, temp: 94, time: 145,
             overall: 3.0, scores: (4.5, 2.0, 2.5, 2.5, 2.5),
             takeaway: "太酸，尖锐", tweaks: [NextTweak(dimension: .grind, direction: .finer)])
        brew(yirga, daysAgo: 6, grind: 23, dose: 15, water: 240, temp: 92, time: 150,
             overall: 3.5, scores: (3.8, 3.0, 3.0, 3.0, 3.2),
             takeaway: "好一点，还是偏酸", tweaks: [NextTweak(dimension: .temp, direction: .down)])
        brew(yirga, daysAgo: 3, grind: 22.5, dose: 15, water: 240, temp: 90, time: 156,
             overall: 4.0, scores: (3.3, 3.8, 3.3, 3.5, 3.8),
             takeaway: "甜感出来了！", tweaks: [NextTweak(dimension: .grind, direction: .finer)])
        brew(yirga, daysAgo: 1, grind: 22, dose: 15, water: 240, temp: 90, time: 156,
             overall: 4.5, scores: (3.5, 4.2, 3.6, 4.0, 4.3),
             takeaway: "平衡又甜，最佳！", best: true)

        // 2) 调试中：哥伦比亚蜜处理
        let col = Bean(name: "哥伦比亚 蜜处理", bagWeightGrams: 250)
        col.originText = "哥伦比亚 慧兰"
        col.process = .honey
        col.roastLevel = .medium
        col.roastDate = day(6)
        col.flavorTags = ["焦糖", "可可"]
        col.remainingGrams = 205
        context.insert(col)
        brew(col, daysAgo: 4, grind: 26, dose: 16, water: 256, temp: 92, time: 165,
             overall: 3.5, scores: (3.0, 3.5, 4.0, 3.5, 3.5),
             takeaway: "醇厚不错，尾巴有点苦", tweaks: [NextTweak(dimension: .ratio, direction: .up)])
        brew(col, daysAgo: 1, grind: 27, dose: 16, water: 272, temp: 91, time: 160,
             overall: 3.8, scores: (3.2, 3.8, 3.8, 3.8, 3.8),
             takeaway: "稀一点更干净")

        // 3) 新豆：巴拿马瑰夏（未冲）
        let geisha = Bean(name: "巴拿马 瑰夏", bagWeightGrams: 100)
        geisha.originText = "巴拿马 翡翠庄园"
        geisha.process = .natural
        geisha.roastLevel = .light
        geisha.roastDate = day(3)
        geisha.flavorTags = ["白桃", "茉莉", "蜂蜜"]
        context.insert(geisha)

        // 4) 已喝完 + 配方库：肯尼亚
        let kenya = Bean(name: "肯尼亚 AA", bagWeightGrams: 200)
        kenya.originText = "肯尼亚 涅里"
        kenya.process = .washed
        kenya.roastLevel = .mediumLight
        kenya.roastDate = day(40)
        kenya.flavorTags = ["黑加仑", "番茄"]
        kenya.remainingGrams = 0
        kenya.archived = true
        kenya.archivedAt = day(2)
        context.insert(kenya)
        brew(kenya, daysAgo: 20, grind: 23, dose: 15, water: 240, temp: 92, time: 150,
             overall: 4.2, scores: (4.0, 3.8, 3.5, 4.0, 4.0),
             takeaway: "莓果炸裂", best: true)

        let recipe = RecipeArchive()
        recipe.sourceBeanName = "肯尼亚 AA"
        recipe.originText = "肯尼亚 涅里"
        recipe.processRaw = Process.washed.rawValue
        recipe.roastLevelRaw = RoastLevel.mediumLight.rawValue
        recipe.flavorTags = ["黑加仑", "番茄"]
        recipe.grind = 23; recipe.dose = 15; recipe.water = 240; recipe.temp = 92
        recipe.totalTime = 150
        recipe.pours = PourTemplate.three.stages(dose: 15, water: 240)
        recipe.overall = 4.2
        recipe.takeaway = "莓果炸裂"
        context.insert(recipe)

        try? context.save()
    }
}
#endif
