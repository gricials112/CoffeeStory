import SwiftUI

struct PrepareView: View {
    let controller: BrewFlowController
    @Bindable var session: ActiveBrewSession
    @AppStorage(SettingsKey.pourCumulative) private var cumulative = true
    @State private var template: PourTemplate = .three

    private var tempBinding: Binding<Double> {
        Binding(get: { session.temp ?? 92 }, set: { session.temp = $0 })
    }
    private var doseBinding: Binding<Double> {
        Binding(get: { session.dose }, set: { controller.setDose($0) })
    }
    private var waterBinding: Binding<Double> {
        Binding(get: { session.water }, set: { controller.setWater($0) })
    }
    private var grindBinding: Binding<Double> {
        Binding(get: { session.grind }, set: { session.grind = $0 })
    }

    private var hint: [NextTweak] {
        guard controller.bean.status != .dialedIn else { return [] }
        return controller.bean.latestBrew?.nextTweaks ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                if !hint.isEmpty {
                    HStack(alignment: .top, spacing: Space.sm) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(DT.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("上次说要调").font(.caption.weight(.semibold)).foregroundStyle(DT.coffee)
                            Text(hint.map(\.label).joined(separator: "、"))
                                .font(.subheadline).foregroundStyle(DT.ink)
                            if let note = controller.bean.latestBrew?.nextTweakNote, !note.isEmpty {
                                Text(note).font(.caption).foregroundStyle(DT.inkSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(Space.md)
                    .background(DT.amberSoft, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }

                // 参数
                VStack(spacing: Space.md) {
                    StepperField(title: "研磨度", value: grindBinding, range: 0...100, step: 0.5)
                    HStack(spacing: Space.sm) {
                        StepperField(title: "粉量", unit: "g", value: doseBinding, range: 1...200, step: 0.5, compact: true)
                        StepperField(title: "水量", unit: "g", value: waterBinding, range: 1...3000, step: 5, compact: true)
                    }
                    HStack {
                        Text("粉水比").font(.footnote).foregroundStyle(DT.inkSecondary)
                        Text(NumFmt.ratio(controller.ratio))
                            .font(.roundedNumber(16, weight: .bold)).foregroundStyle(DT.amber)
                        Spacer()
                        ForEach([15.0, 16.0, 17.0], id: \.self) { r in
                            Button { controller.setRatio(r) } label: {
                                Chip(text: "1:\(Int(r))", selected: abs(controller.ratio - r) < 0.05)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    StepperField(title: "水温", unit: "℃", value: tempBinding, range: 60...100, step: 1)
                }
                .surfaceCard()

                // 注水模板
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("注水分段").font(.headline).foregroundStyle(DT.ink)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(PourTemplate.allCases) { t in
                                Button {
                                    template = t
                                    controller.applyTemplate(t)
                                } label: {
                                    Chip(text: t.label, selected: template == t)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Toggle(isOn: $cumulative) {
                        Text("按累计水量").font(.caption).foregroundStyle(DT.inkSecondary)
                    }
                    .tint(DT.amber)
                    PourPlanEditor(pours: Binding(get: { session.pours }, set: { session.pours = $0 }),
                                   cumulative: cumulative)
                }
                .surfaceCard()
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { controller.startTimer() }
            } label: {
                Label("开始计时", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .glassProminentButtonStyle()
            .tint(DT.amber)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.sm)
        }
    }
}

// MARK: - 分段计划编辑
struct PourPlanEditor: View {
    @Binding var pours: [PourStage]
    var cumulative: Bool

    private func waterShown(_ idx: Int) -> Double {
        if cumulative { return pours[idx].targetWaterCumulative }
        let prev = idx > 0 ? pours[idx - 1].targetWaterCumulative : 0
        return pours[idx].targetWaterCumulative - prev
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            ForEach(Array(pours.enumerated()), id: \.element.id) { idx, stage in
                HStack(spacing: Space.sm) {
                    Text(stage.label)
                        .font(.subheadline).foregroundStyle(DT.ink)
                        .frame(width: 64, alignment: .leading)
                    Spacer()
                    Text("\(NumFmt.g(waterShown(idx)))g")
                        .font(.caption.monospacedDigit()).foregroundStyle(DT.inkSecondary)
                    if let t = stage.targetTime {
                        Text("@ \(TimeFmt.mmss(t))")
                            .font(.caption.monospacedDigit()).foregroundStyle(DT.inkTertiary)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, Space.md)
                .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
        }
    }
}
