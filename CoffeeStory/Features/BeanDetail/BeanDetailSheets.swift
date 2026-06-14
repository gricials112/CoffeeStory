import SwiftUI
import SwiftData

// MARK: - 校准剩余克数
struct CalibrateSheet: View {
    @Bindable var bean: Bean
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.lg) {
                Text("称一下，把实际剩余克数填进来。")
                    .font(.subheadline).foregroundStyle(DT.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StepperField(title: "剩余克数", unit: "g", value: $value,
                             range: 0...bean.bagWeightGrams, step: 1)
                Spacer()
            }
            .padding(Space.xl)
            .background(DT.canvas)
            .navigationTitle("校准剩余")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        bean.remainingGrams = value.clampedTo(0...bean.bagWeightGrams)
                        Haptics.success(); dismiss()
                    }
                }
            }
            .onAppear { value = bean.remainingGrams }
            .presentationDetents([.height(240)])
        }
    }
}

// MARK: - 编辑历史复盘
struct BrewEditSheet: View {
    @Bindable var bean: Bean
    @Bindable var brew: Brew
    @Environment(\.dismiss) private var dismiss

    @State private var grind: Double = 20
    @State private var dose: Double = 15
    @State private var water: Double = 240
    @State private var hasTemp = true
    @State private var temp: Double = 92
    @State private var totalTime: Double = 0
    @State private var record = false
    @State private var scores = FlavorScores()
    @State private var takeaway = ""
    @State private var tweaks: [NextTweak] = []
    @State private var note = ""
    @State private var isBest = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    VStack(spacing: Space.md) {
                        StepperField(title: "研磨度", value: $grind, range: 0...100, step: 0.5)
                        HStack(spacing: Space.md) {
                            StepperField(title: "粉量", unit: "g", value: $dose, range: 1...200, step: 0.5)
                            StepperField(title: "水量", unit: "g", value: $water, range: 1...3000, step: 5)
                        }
                        Toggle("记录水温", isOn: $hasTemp.animation()).tint(DT.amber)
                        if hasTemp {
                            StepperField(title: "水温", unit: "℃", value: $temp, range: 60...100, step: 1)
                        }
                        StepperField(title: "总时间", unit: "", value: $totalTime, range: 0...3600, step: 5,
                                     format: { TimeFmt.mmss($0) })
                    }
                    .surfaceCard()

                    FlavorScoreEditor(record: $record, scores: $scores).surfaceCard()
                    TakeawayEditor(text: $takeaway).surfaceCard()
                    NextTweakEditor(tweaks: $tweaks, note: $note).surfaceCard()

                    Toggle(isOn: $isBest.animation()) {
                        Label("设为这包的最佳参数", systemImage: "star.fill")
                            .font(.headline).foregroundStyle(isBest ? DT.gold : DT.ink)
                    }
                    .tint(DT.gold).surfaceCard()
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.lg)
            }
            .background(DT.canvas)
            .navigationTitle("编辑复盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        grind = brew.grind; dose = brew.dose; water = brew.water
        if let t = brew.temp { hasTemp = true; temp = t } else { hasTemp = false }
        totalTime = brew.totalTime
        record = brew.hasAnyScore
        scores = FlavorScores(
            acidity: brew.acidity ?? 3, sweetness: brew.sweetness ?? 3, body: brew.bodyScore ?? 3,
            aftertaste: brew.aftertaste ?? 3, balance: brew.balance ?? 3, overall: brew.overall ?? 3.5)
        takeaway = brew.takeaway; tweaks = brew.nextTweaks; note = brew.nextTweakNote
        isBest = brew.isBest
    }

    private func save() {
        let deltaDose = dose - brew.dose
        bean.remainingGrams = (bean.remainingGrams - deltaDose).clampedTo(0...bean.bagWeightGrams)

        brew.grind = grind; brew.dose = dose; brew.water = water
        brew.temp = hasTemp ? temp : nil
        brew.totalTime = totalTime
        brew.acidity = record ? scores.acidity : nil
        brew.sweetness = record ? scores.sweetness : nil
        brew.bodyScore = record ? scores.body : nil
        brew.aftertaste = record ? scores.aftertaste : nil
        brew.balance = record ? scores.balance : nil
        brew.overall = record ? scores.overall : nil
        brew.takeaway = takeaway.trimmingCharacters(in: .whitespaces)
        brew.nextTweaks = tweaks
        brew.nextTweakNote = note.trimmingCharacters(in: .whitespaces)

        if isBest {
            for b in bean.brews { b.isBest = false }
            brew.isBest = true
        } else {
            brew.isBest = false
        }
        Haptics.success(); dismiss()
    }
}
