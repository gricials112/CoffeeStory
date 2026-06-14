import SwiftUI

enum RelativeFmt {
    static func short(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: date),
                                      to: cal.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0:  return "今天"
        case 1:  return "昨天"
        case 2...6: return "\(days) 天前"
        default: return date.formatted(.dateTime.month().day())
        }
    }
}

struct BrewTimelineCard: View {
    let brew: Brew
    let attempt: Int
    var compareMode: Bool = false
    var selected: Bool = false
    var onSetBest: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onShare: () -> Void = {}

    private func paramChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption.monospacedDigit())
        }
        .foregroundStyle(DT.inkSecondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                if compareMode {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? DT.amber : DT.inkTertiary)
                }
                Text("第 \(attempt) 次")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DT.ink)
                if brew.isBest {
                    Label("最佳", systemImage: "star.fill")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(DT.goldSoft, in: Capsule())
                        .foregroundStyle(DT.gold)
                }
                Spacer()
                if let overall = brew.overall {
                    Text(NumFmt.score(overall))
                        .font(.roundedNumber(17, weight: .bold))
                        .foregroundStyle(brew.isBest ? DT.gold : DT.amber)
                    Text("分").font(.caption2).foregroundStyle(DT.inkTertiary)
                }
                Text(RelativeFmt.short(brew.createdAt))
                    .font(.caption).foregroundStyle(DT.inkTertiary)
                if !compareMode {
                    Menu {
                        if !brew.isBest { Button { onSetBest() } label: { Label("设为最佳", systemImage: "star") } }
                        Button { onShare() } label: { Label("分享", systemImage: "square.and.arrow.up") }
                        Button { onEdit() } label: { Label("编辑复盘", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").font(.subheadline).foregroundStyle(DT.inkTertiary)
                            .frame(width: 28, height: 28)
                    }
                }
            }

            FlowLayout(spacing: 10) {
                paramChip("dial.medium", "研磨 \(NumFmt.g(brew.grind))")
                paramChip("scalemass", NumFmt.ratio(brew.ratio))
                if let t = brew.temp { paramChip("thermometer.medium", "\(NumFmt.g(t))℃") }
                if brew.totalTime > 0 { paramChip("timer", TimeFmt.mmss(brew.totalTime)) }
            }

            if !brew.takeaway.isEmpty {
                Text(brew.takeaway)
                    .font(.subheadline).italic()
                    .foregroundStyle(DT.ink)
            }

            if !brew.nextTweaks.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right").font(.caption2).foregroundStyle(DT.coffee)
                    Text("下次：" + brew.nextTweaks.map(\.label).joined(separator: "、"))
                        .font(.caption).foregroundStyle(DT.coffee)
                }
            }
        }
        .surfaceCard(tint: brew.isBest ? DT.goldSoft.opacity(0.5) : DT.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(brew.isBest ? DT.gold.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }
}
