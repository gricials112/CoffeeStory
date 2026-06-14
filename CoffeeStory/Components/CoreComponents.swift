import SwiftUI

// MARK: - 萃取环（标志性组件）
struct ExtractionRing: View {
    var progress: Double                 // 0...1
    var lineWidthRatio: CGFloat = 0.11
    var track: Color = DT.amberSoft
    var fill: Color = DT.amber

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let lw = d * lineWidthRatio
            ZStack {
                Circle()
                    .stroke(track, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                Circle()
                    .trim(from: 0, to: max(0.0001, min(1, progress)))
                    .stroke(fill, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
            }
            .padding(lw / 2)
        }
    }
}

// MARK: - 状态徽标
struct StatusBadge: View {
    let status: BeanStatus
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
            Text(status.label)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(status.color)
        .background(status.color.opacity(0.14), in: Capsule())
    }
}

// MARK: - 通用 Chip
struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var selected: Bool = false
    var color: Color = DT.amber
    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.subheadline.weight(selected ? .semibold : .regular))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(selected ? Color.white : DT.inkSecondary)
        .background(selected ? color : DT.surfaceSunken, in: Capsule())
        .overlay(Capsule().strokeBorder(DT.hairline, lineWidth: selected ? 0 : 0.5))
        .contentShape(Capsule())
    }
}

// MARK: - 流式换行布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, totalWidth: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return CGSize(width: min(maxWidth, totalWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 风味雷达
struct RadarSeries: Identifiable {
    let id = UUID()
    var values: [Double]          // 与 FlavorDimension.allCases 对齐，0...5
    var color: Color
    var filled: Bool = true
}

struct FlavorRadar: View {
    var series: [RadarSeries]
    var maxValue: Double = 5
    var axes: [String] = FlavorDimension.allCases.map(\.label)

    var body: some View {
        Canvas { ctx, size in
            let n = axes.count
            guard n > 2 else { return }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 20
            func pt(_ axis: Int, _ frac: Double) -> CGPoint {
                let a = -Double.pi / 2 + Double(axis) * 2 * Double.pi / Double(n)
                return CGPoint(x: c.x + cos(a) * r * frac, y: c.y + sin(a) * r * frac)
            }
            // 网格环
            for ring in 1...4 {
                let frac = Double(ring) / 4
                var p = Path()
                for i in 0..<n {
                    let q = pt(i, frac)
                    if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                }
                p.closeSubpath()
                ctx.stroke(p, with: .color(DT.hairline), lineWidth: 0.5)
            }
            // 辐条
            for i in 0..<n {
                var p = Path(); p.move(to: c); p.addLine(to: pt(i, 1))
                ctx.stroke(p, with: .color(DT.hairline), lineWidth: 0.5)
            }
            // 数据
            for s in series where s.values.count == n {
                var p = Path()
                for i in 0..<n {
                    let frac = min(1, max(0, s.values[i] / maxValue))
                    let q = pt(i, frac)
                    if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                }
                p.closeSubpath()
                if s.filled { ctx.fill(p, with: .color(s.color.opacity(0.18))) }
                ctx.stroke(p, with: .color(s.color), lineWidth: 2)
            }
        }
        .overlay {
            GeometryReader { geo in
                let n = axes.count
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let r = min(geo.size.width, geo.size.height) / 2 - 20
                ForEach(Array(axes.enumerated()), id: \.offset) { idx, label in
                    let a = -Double.pi / 2 + Double(idx) * 2 * Double.pi / Double(n)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(DT.inkSecondary)
                        .position(x: c.x + cos(a) * (r + 14), y: c.y + sin(a) * (r + 14))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 评分条（0...5，0.5 步进，可拖动）
struct ScoreBar: View {
    let title: String
    var tint: Color
    @Binding var value: Double

    var body: some View {
        HStack(spacing: Space.md) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(title).font(.subheadline).foregroundStyle(DT.ink)
            }
            .frame(width: 64, alignment: .leading)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(DT.surfaceSunken).frame(height: 10)
                    Capsule().fill(tint).frame(width: max(10, w * value / 5), height: 10)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let frac = min(1, max(0, g.location.x / w))
                            let snapped = (frac * 10).rounded() / 2
                            if snapped != value { Haptics.selection() }
                            value = snapped
                        }
                )
            }
            .frame(height: 28)

            Text(NumFmt.score(value))
                .font(.roundedNumber(15))
                .foregroundStyle(DT.inkSecondary)
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(NumFmt.score(value)) 分")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: value = min(5, value + 0.5)
            case .decrement: value = max(0, value - 0.5)
            default: break
            }
        }
    }
}
