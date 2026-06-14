import Foundation

private struct ExportPour: Codable {
    var label: String
    var targetWaterCumulative: Double
    var targetTime: Double?
    var actualAt: Double?
}

private struct ExportBrew: Codable {
    var createdAt: Date
    var grind: Double
    var dose: Double
    var water: Double
    var ratio: Double
    var temp: Double?
    var totalTime: Double
    var pours: [ExportPour]
    var overall: Double?
    var acidity: Double?
    var sweetness: Double?
    var body: Double?
    var aftertaste: Double?
    var balance: Double?
    var takeaway: String
    var nextTweaks: [String]
    var isBest: Bool
}

private struct ExportBean: Codable {
    var name: String
    var roaster: String
    var origin: String
    var process: String
    var roastLevel: String
    var roastDate: Date?
    var bagWeightGrams: Double
    var remainingGrams: Double
    var flavorTags: [String]
    var archived: Bool
    var brews: [ExportBrew]
}

private struct ExportRoot: Codable {
    var app = "CoffeeStory · 这包怎么冲"
    var version = "1.0"
    var exportedAt: Date
    var beans: [ExportBean]
}

enum ExportService {
    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    static func makeJSON(beans: [Bean]) -> Data? {
        let root = ExportRoot(
            exportedAt: Date(),
            beans: beans.map { bean in
                ExportBean(
                    name: bean.name,
                    roaster: bean.roaster,
                    origin: bean.originText,
                    process: bean.process.label,
                    roastLevel: bean.roastLevel.label,
                    roastDate: bean.roastDate,
                    bagWeightGrams: bean.bagWeightGrams,
                    remainingGrams: bean.remainingGrams,
                    flavorTags: bean.flavorTags,
                    archived: bean.archived,
                    brews: bean.orderedBrews.map { brew in
                        ExportBrew(
                            createdAt: brew.createdAt,
                            grind: brew.grind,
                            dose: brew.dose,
                            water: brew.water,
                            ratio: brew.ratio,
                            temp: brew.temp,
                            totalTime: brew.totalTime,
                            pours: brew.pours.map {
                                ExportPour(label: $0.label,
                                           targetWaterCumulative: $0.targetWaterCumulative,
                                           targetTime: $0.targetTime,
                                           actualAt: $0.actualAt)
                            },
                            overall: brew.overall,
                            acidity: brew.acidity,
                            sweetness: brew.sweetness,
                            body: brew.bodyScore,
                            aftertaste: brew.aftertaste,
                            balance: brew.balance,
                            takeaway: brew.takeaway,
                            nextTweaks: brew.nextTweaks.map(\.label),
                            isBest: brew.isBest
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(root)
    }

    static func writeTempFile(beans: [Bean]) -> ExportFile? {
        guard let data = makeJSON(beans: beans) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoffeeStory-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url)
            return ExportFile(url: url)
        } catch {
            return nil
        }
    }
}
