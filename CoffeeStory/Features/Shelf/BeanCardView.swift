import SwiftUI

struct BeanCardView: View {
    let bean: Bean

    private var subtitle: String {
        [bean.originText.isEmpty ? nil : bean.originText, bean.process.label]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top, spacing: Space.md) {
                BeanCover(data: bean.coverImageData, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(bean.name.isEmpty ? "未命名" : bean.name)
                        .font(.headline)
                        .foregroundStyle(DT.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DT.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                StatusBadge(status: bean.status)
            }

            HStack(spacing: Space.lg) {
                // 养豆 / 赏味
                HStack(spacing: 5) {
                    Circle().fill(bean.tasteStatus.color).frame(width: 7, height: 7)
                    if let d = bean.restDays {
                        Text("养豆 \(d) 天")
                            .font(.footnote).foregroundStyle(DT.inkSecondary)
                        Text("· \(bean.tasteStatus.label)")
                            .font(.footnote).foregroundStyle(bean.tasteStatus.color)
                    } else {
                        Text(bean.tasteStatus.label)
                            .font(.footnote).foregroundStyle(DT.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
                // 评分 / 次数
                if let best = bean.bestScore {
                    Label(NumFmt.score(best), systemImage: "star.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DT.gold)
                } else if bean.brewCount > 0 {
                    Text("调试中 · \(bean.brewCount) 次")
                        .font(.footnote).foregroundStyle(DT.amber)
                } else {
                    Text("还没冲过")
                        .font(.footnote).foregroundStyle(DT.inkTertiary)
                }
            }

            // 消耗进度
            HStack(spacing: Space.sm) {
                ProgressView(value: bean.consumedProgress)
                    .tint(DT.amber)
                Text("剩 \(NumFmt.g(bean.remainingGrams))g")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DT.inkSecondary)
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 封面
struct BeanCover: View {
    let data: Data?
    var size: CGFloat = 52
    var body: some View {
        Group {
            if let data, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [DT.coffee.opacity(0.85), DT.coffee],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(DT.hairline, lineWidth: 0.5))
    }
}
