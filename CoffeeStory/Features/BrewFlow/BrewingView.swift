import SwiftUI

struct BrewingView: View {
    let controller: BrewFlowController
    @AppStorage(SettingsKey.keepScreenOn) private var keepScreenOn = true
    @AppStorage(SettingsKey.pourCumulative) private var cumulative = true
    @Namespace private var glassNS

    private var session: ActiveBrewSession { controller.session }
    private var stages: [PourStage] { session.pours }
    private var currentIndex: Int { min(session.currentStageIndex, max(0, stages.count - 1)) }
    private var currentStage: PourStage? { stages.indices.contains(currentIndex) ? stages[currentIndex] : nil }
    private var totalWater: Double { stages.last?.targetWaterCumulative ?? session.water }

    private var pouredWater: Double {
        stages.filter { $0.actualAt != nil }.map(\.targetWaterCumulative).max() ?? 0
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            TimelineView(.periodic(from: Date(), by: 0.1)) { ctx in
                let elapsed = session.elapsed(at: ctx.date)
                ZStack {
                    ExtractionRing(progress: totalWater > 0 ? pouredWater / totalWater : 0)
                    VStack(spacing: 4) {
                        Text(TimeFmt.mmss(elapsed))
                            .font(.system(size: 68, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DT.ink)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        if let stage = currentStage {
                            Text(stage.label)
                                .font(.headline).foregroundStyle(DT.amber)
                            HStack(spacing: 4) {
                                Text("目标 \(NumFmt.g(stage.targetWaterCumulative))g")
                                if let t = stage.targetTime {
                                    Text("· \(TimeFmt.mmss(t))")
                                }
                            }
                            .font(.caption).foregroundStyle(DT.inkTertiary)
                        }
                    }
                }
                .frame(width: 280, height: 280)
                .accessibilityElement()
                .accessibilityLabel("已用时")
                .accessibilityValue(TimeFmt.mmss(elapsed))
            }

            Text("累计注水 \(NumFmt.g(pouredWater)) / \(NumFmt.g(totalWater)) g")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(DT.inkSecondary)

            stageList

            Spacer(minLength: 0)
            controls
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.lg)
        .keepAwake(keepScreenOn)
    }

    private var stageList: some View {
        VStack(spacing: 6) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { idx, stage in
                HStack(spacing: Space.sm) {
                    Image(systemName: stage.actualAt != nil ? "checkmark.circle.fill"
                          : (idx == currentIndex ? "circle.dotted" : "circle"))
                        .foregroundStyle(stage.actualAt != nil ? DT.peak
                                         : (idx == currentIndex ? DT.amber : DT.inkTertiary))
                    Text(stage.label).font(.subheadline)
                        .foregroundStyle(idx == currentIndex ? DT.ink : DT.inkSecondary)
                    Spacer()
                    Text("\(NumFmt.g(stage.targetWaterCumulative))g")
                        .font(.caption.monospacedDigit()).foregroundStyle(DT.inkTertiary)
                    if let a = stage.actualAt {
                        Text(TimeFmt.mmss(a))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(DT.peak)
                            .frame(width: 44, alignment: .trailing)
                    } else {
                        Text("—").font(.caption).foregroundStyle(DT.inkTertiary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .padding(.vertical, 7).padding(.horizontal, Space.md)
                .background(idx == currentIndex ? DT.amberSoft.opacity(0.6) : Color.clear,
                            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
        }
    }

    private var hasNext: Bool { currentIndex < stages.count - 1 }

    private var controls: some View {
        GlassContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button { controller.undoStage() } label: {
                    Image(systemName: "arrow.uturn.backward").frame(width: 52, height: 52)
                }
                .glassButtonStyle()
                .disabled(pouredWater == 0)

                Button { controller.togglePause() } label: {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 52, height: 52)
                }
                .glassButtonStyle()

                if hasNext {
                    Button { controller.nextStage() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.fill")
                            Text("下一段")
                        }
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .glassProminentButtonStyle()
                    .tint(DT.amber)

                    Button { withAnimation { controller.finishBrewing() } } label: {
                        Image(systemName: "stop.fill").frame(width: 52, height: 52)
                    }
                    .glassButtonStyle()
                    .tint(DT.coffee)
                } else {
                    Button { withAnimation { controller.finishBrewing() } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text("结束")
                        }
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .glassProminentButtonStyle()
                    .tint(DT.amber)
                }
            }
        }
    }
}
