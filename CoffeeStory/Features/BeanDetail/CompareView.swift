import SwiftUI

struct CompareView: View {
    let brews: [Brew]
    let attemptMap: [UUID: Int]
    @Environment(\.dismiss) private var dismiss

    private let palette: [Color] = [DT.amber, DT.resting, DT.bodyFlavor]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    radarCard
                    tableCard
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.lg)
            }
            .background(DT.canvas)
            .navigationTitle("对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }

    private var radarCard: some View {
        VStack(spacing: Space.md) {
            FlavorRadar(series: brews.enumerated().map { idx, brew in
                RadarSeries(
                    values: FlavorDimension.allCases.map { brew.score(for: $0) ?? 0 },
                    color: palette[idx % palette.count],
                    filled: false)
            })
            .frame(height: 200)
            HStack(spacing: Space.lg) {
                ForEach(Array(brews.enumerated()), id: \.element.id) { idx, brew in
                    HStack(spacing: 5) {
                        Circle().fill(palette[idx % palette.count]).frame(width: 8, height: 8)
                        Text("第 \(attemptMap[brew.id] ?? 0) 次").font(.caption).foregroundStyle(DT.inkSecondary)
                    }
                }
            }
        }
        .surfaceCard()
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            row("", brews.map { "第\(attemptMap[$0.id] ?? 0)次" }, header: true)
            Divider()
            paramRow("研磨", \.grind) { NumFmt.g($0) }
            paramRow("粉量", \.dose) { "\(NumFmt.g($0))g" }
            paramRow("水量", \.water) { "\(NumFmt.g($0))g" }
            paramRow("粉水比", \.ratio) { NumFmt.ratio($0) }
            ratioTempRow
            paramRow("总时间", \.totalTime) { TimeFmt.mmss($0) }
            Divider()
            scoreRow("总分") { $0.overall }
            scoreRow("酸") { $0.acidity }
            scoreRow("甜") { $0.sweetness }
            scoreRow("醇厚") { $0.bodyScore }
            scoreRow("余韵") { $0.aftertaste }
            scoreRow("平衡") { $0.balance }
        }
        .surfaceCard(padding: Space.md)
    }

    private var ratioTempRow: some View {
        let values = brews.map { $0.temp.map { "\(NumFmt.g($0))℃" } ?? "—" }
        let changed = Set(values).count > 1
        return row("水温", values, changed: changed)
    }

    private func paramRow(_ title: String, _ key: KeyPath<Brew, Double>, _ fmt: (Double) -> String) -> some View {
        let raw = brews.map { $0[keyPath: key] }
        let values = raw.map(fmt)
        let changed = Set(raw).count > 1
        return row(title, values, changed: changed)
    }

    private func scoreRow(_ title: String, _ get: (Brew) -> Double?) -> some View {
        let raw = brews.map { get($0) }
        let values = raw.map { NumFmt.score($0) }
        let changed = Set(raw.map { $0 ?? -1 }).count > 1
        return row(title, values, changed: changed)
    }

    private func row(_ title: String, _ values: [String], header: Bool = false, changed: Bool = false) -> some View {
        HStack(spacing: Space.sm) {
            Text(title)
                .font(.caption.weight(header ? .bold : .regular))
                .foregroundStyle(DT.inkSecondary)
                .frame(width: 56, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                Text(v)
                    .font(header ? .caption.weight(.bold) : .subheadline.monospacedDigit().weight(changed ? .bold : .regular))
                    .foregroundStyle(header ? DT.ink : (changed ? DT.amber : DT.ink))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 7)
    }
}
