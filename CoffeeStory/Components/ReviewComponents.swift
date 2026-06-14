import SwiftUI

struct FlavorScores {
    var acidity: Double = 3
    var sweetness: Double = 3
    var body: Double = 3
    var aftertaste: Double = 3
    var balance: Double = 3
    var overall: Double = 3.5

    var radarValues: [Double] { [acidity, sweetness, body, aftertaste, balance] }
}

// MARK: - 风味评分编辑器
struct FlavorScoreEditor: View {
    @Binding var record: Bool
    @Binding var scores: FlavorScores

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Toggle(isOn: $record.animation()) {
                Text("记录风味评分").font(.headline).foregroundStyle(DT.ink)
            }
            .tint(DT.amber)

            if record {
                HStack(alignment: .center, spacing: Space.lg) {
                    FlavorRadar(series: [RadarSeries(values: scores.radarValues, color: DT.amber)])
                        .frame(width: 150, height: 150)
                    VStack(spacing: 2) {
                        Text("总分").font(.caption).foregroundStyle(DT.inkSecondary)
                        Text(NumFmt.score(scores.overall))
                            .font(.roundedNumber(40, weight: .bold))
                            .foregroundStyle(DT.gold)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: scores.overall)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: Space.sm) {
                    ScoreBar(title: "总分", tint: DT.gold, value: $scores.overall)
                    Divider()
                    ScoreBar(title: FlavorDimension.acidity.label, tint: DT.acidity, value: $scores.acidity)
                    ScoreBar(title: FlavorDimension.sweetness.label, tint: DT.sweet, value: $scores.sweetness)
                    ScoreBar(title: FlavorDimension.body.label, tint: DT.bodyFlavor, value: $scores.body)
                    ScoreBar(title: FlavorDimension.aftertaste.label, tint: DT.after, value: $scores.aftertaste)
                    ScoreBar(title: FlavorDimension.balance.label, tint: DT.balance, value: $scores.balance)
                }
            }
        }
    }
}

// MARK: - 一句话小结
struct TakeawayEditor: View {
    @Binding var text: String
    private let quick = ["太酸", "偏苦", "水感", "平衡", "甜感足", "尾韵干净", "醇厚", "风味弱"]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("一句话小结").font(.headline).foregroundStyle(DT.ink)
            TextField("这一杯喝起来…", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .padding(Space.md)
                .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            FlowLayout(spacing: 6) {
                ForEach(quick, id: \.self) { word in
                    Button { append(word) } label: { Chip(text: word) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func append(_ word: String) {
        Haptics.selection()
        if text.isEmpty { text = word }
        else if !text.contains(word) { text += " " + word }
    }
}

// MARK: - 下次怎么调
struct NextTweakEditor: View {
    @Binding var tweaks: [NextTweak]
    @Binding var note: String

    private func isOn(_ dim: TweakDimension, _ dir: TweakDirection) -> Bool {
        tweaks.contains { $0.dimension == dim && $0.direction == dir }
    }
    private func toggle(_ dim: TweakDimension, _ dir: TweakDirection) {
        Haptics.selection()
        if isOn(dim, dir) {
            tweaks.removeAll { $0.dimension == dim && $0.direction == dir }
        } else {
            tweaks.removeAll { $0.dimension == dim }  // 每维度仅一个方向
            tweaks.append(NextTweak(dimension: dim, direction: dir))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("下次怎么调").font(.headline).foregroundStyle(DT.ink)
            ForEach(TweakDimension.allCases) { dim in
                HStack(alignment: .center, spacing: Space.sm) {
                    Text(dim.label)
                        .font(.subheadline)
                        .foregroundStyle(DT.inkSecondary)
                        .frame(width: 48, alignment: .leading)
                    FlowLayout(spacing: 6) {
                        ForEach(dim.directions) { dir in
                            Button { toggle(dim, dir) } label: {
                                Chip(text: dir.label, selected: isOn(dim, dir), color: DT.coffee)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            TextField("补充一句（可选）", text: $note)
                .font(.subheadline)
                .padding(Space.md)
                .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
    }
}
