import SwiftUI

struct PaywallView: View {
    @Environment(Entitlements.self) private var ent
    @Environment(\.dismiss) private var dismiss

    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }
    private let benefits: [Benefit] = [
        .init(icon: "infinity", title: "无限豆子与冲煮", detail: "想记多少包、冲多少次都可以"),
        .init(icon: "chart.line.uptrend.xyaxis", title: "完整收敛曲线", detail: "看清这包从酸到甜的全过程"),
        .init(icon: "rectangle.on.rectangle.angled", title: "多次对比", detail: "并排 diff 出到底变了哪个参数"),
        .init(icon: "books.vertical.fill", title: "配方库复用", detail: "毕业归档，下次买豆少走弯路"),
        .init(icon: "square.and.arrow.up", title: "高级分享卡 · 去水印", detail: "隐藏豆名、干净导出"),
        .init(icon: "tray.and.arrow.down", title: "数据导出", detail: "JSON 备份，数据永远是你的")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    VStack(spacing: Space.sm) {
                        ZStack {
                            Circle().fill(DT.goldSoft).frame(width: 96, height: 96)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 42)).foregroundStyle(DT.gold)
                        }
                        Text("Brew Pro 永久版")
                            .font(.largeTitle.weight(.bold)).foregroundStyle(DT.ink)
                        Text("一次买断，把这包豆子彻底榨干")
                            .font(.subheadline).foregroundStyle(DT.inkSecondary)
                    }
                    .padding(.top, Space.lg)

                    VStack(spacing: Space.md) {
                        ForEach(benefits) { b in
                            HStack(spacing: Space.md) {
                                Image(systemName: b.icon)
                                    .font(.title3).foregroundStyle(DT.amber)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.title).font(.headline).foregroundStyle(DT.ink)
                                    Text(b.detail).font(.caption).foregroundStyle(DT.inkSecondary)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(Space.lg)
                    .surfaceCard()

                    VStack(spacing: Space.sm) {
                        Button {
                            Task { if await ent.purchase() { dismiss() } }
                        } label: {
                            VStack(spacing: 2) {
                                Text(ent.purchasing ? "处理中…" : "永久解锁 · \(ent.priceText)")
                                    .font(.headline)
                                Text("首发限时价").font(.caption2).opacity(0.9)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(DT.amber)
                        .disabled(ent.purchasing)

                        Button("恢复购买") { Task { await ent.restore(); if ent.isPro { dismiss() } } }
                            .font(.subheadline).foregroundStyle(DT.inkSecondary)
                    }
                    .padding(.horizontal, Space.xl)

                    Text("一次性付费，永久有效，无订阅。\n免费版可记录 2 包豆子、每包 6 次冲煮。")
                        .font(.caption2).foregroundStyle(DT.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Space.xl)
                }
                .padding(.horizontal, Space.xl)
            }
            .background(DT.canvas)
            .navigationTitle("升级 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("以后再说") { dismiss() } }
            }
        }
    }
}
