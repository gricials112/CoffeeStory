import SwiftUI
import Charts

enum CurveAxis: String, CaseIterable, Identifiable {
    case overall, acidity, sweetness, body, aftertaste, balance, grind, temp, ratio
    var id: String { rawValue }
    var label: String {
        switch self {
        case .overall:    "总分"
        case .acidity:    "酸"
        case .sweetness:  "甜"
        case .body:       "醇厚"
        case .aftertaste: "余韵"
        case .balance:    "平衡"
        case .grind:      "研磨"
        case .temp:       "水温"
        case .ratio:      "粉水比"
        }
    }
    var isFlavor: Bool {
        switch self {
        case .grind, .temp, .ratio: false
        default: true
        }
    }
    func value(_ b: Brew) -> Double? {
        switch self {
        case .overall:    b.overall
        case .acidity:    b.acidity
        case .sweetness:  b.sweetness
        case .body:       b.bodyScore
        case .aftertaste: b.aftertaste
        case .balance:    b.balance
        case .grind:      b.grind
        case .temp:       b.temp
        case .ratio:      b.ratio
        }
    }
    static var flavorAxes: [CurveAxis] { [.overall, .acidity, .sweetness, .body, .aftertaste, .balance] }
    static var paramAxes: [CurveAxis] { [.grind, .temp, .ratio] }
}

private struct CurvePoint: Identifiable {
    let id = UUID()
    let n: Int
    let value: Double?
    let isBest: Bool
    let segment: Int
}

struct ConvergenceChart: View {
    let brews: [Brew]              // 时间升序
    let axis: CurveAxis

    private var points: [CurvePoint] {
        var seg = 0
        var lastHadValue = false
        return brews.enumerated().map { idx, brew in
            let v = axis.value(brew)
            if v != nil && !lastHadValue { seg += 1 }
            lastHadValue = (v != nil)
            return CurvePoint(n: idx + 1, value: v, isBest: brew.isBest, segment: seg)
        }
    }

    var body: some View {
        let pts = points
        let scored = pts.filter { $0.value != nil }
        Chart {
            ForEach(scored) { p in
                LineMark(
                    x: .value("次", p.n),
                    y: .value(axis.label, p.value ?? 0)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("段", p.segment))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            ForEach(scored) { p in
                PointMark(
                    x: .value("次", p.n),
                    y: .value(axis.label, p.value ?? 0)
                )
                .foregroundStyle(p.isBest ? DT.gold : DT.amber)
                .symbolSize(p.isBest ? 170 : 70)
                .annotation(position: .top, spacing: 4) {
                    if p.isBest {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(DT.gold)
                    }
                }
            }
        }
        .chartForegroundStyleScale(range: Array(repeating: DT.amber, count: 16))
        .chartLegend(.hidden)
        .chartXScale(domain: 0.5...(Double(max(brews.count, 1)) + 0.5))
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                AxisGridLine().foregroundStyle(DT.hairline)
                AxisValueLabel {
                    if let n = value.as(Int.self) { Text("第\(n)次").font(.caption2) }
                }
            }
        }
        .modifier(FlavorDomain(axis: axis))
        .frame(height: 180)
    }
}

private struct FlavorDomain: ViewModifier {
    let axis: CurveAxis
    func body(content: Content) -> some View {
        if axis.isFlavor {
            content.chartYScale(domain: 0...5)
        } else {
            content
        }
    }
}
