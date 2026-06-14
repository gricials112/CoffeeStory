import SwiftUI

struct ShareCardView: View {
    let bean: Bean
    let brew: Brew
    var isPro: Bool = true
    @Environment(\.dismiss) private var dismiss

    // 显示开关（持久化）
    @AppStorage(SettingsKey.shareShowFlavorTags) private var showFlavorTags = true
    @AppStorage(SettingsKey.shareShowSubScores)  private var showSubScores  = false
    @AppStorage(SettingsKey.shareShowGrinder)    private var showGrinder    = false
    @AppStorage(SettingsKey.shareShowRoastInfo)  private var showRoastInfo  = false
    @State private var hideName    = false
    @State private var showBranding = true

    private var effHideName: Bool { isPro && hideName }
    private var effBranding: Bool { isPro ? showBranding : true }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    ShareCard(bean: bean, brew: brew,
                              hideName: effHideName, showBranding: effBranding,
                              showFlavorTags: showFlavorTags,
                              showSubScores: showSubScores,
                              showGrinder: showGrinder,
                              showRoastInfo: showRoastInfo)
                        .frame(width: 320, height: 440)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
                        .padding(.top, Space.lg)

                    VStack(spacing: Space.sm) {
                        Toggle("隐藏豆子名称", isOn: $hideName)
                            .disabled(!isPro)
                        Toggle("显示水印", isOn: $showBranding)
                            .disabled(!isPro)

                        Divider()

                        Toggle("风味标签", isOn: $showFlavorTags)
                        Toggle("细项评分", isOn: $showSubScores)
                        Toggle("磨豆机信息", isOn: $showGrinder)
                            .disabled(!bean.grinderNote.isEmpty ? false : true)
                        Toggle("烘焙信息", isOn: $showRoastInfo)
                            .disabled(bean.roastDate != nil ? false : true)

                        if !isPro {
                            HStack(spacing: 5) {
                                Image(systemName: "lock.fill").font(.caption2)
                                Text("升级 Pro 可隐藏豆名、去水印")
                            }
                            .font(.caption).foregroundStyle(DT.inkTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .tint(DT.amber)
                    .padding(.horizontal, Space.xl)
                }
                .padding(.bottom, Space.xl)
            }
            .background(DT.canvas)
            .navigationTitle("分享这杯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: renderImage(),
                              preview: SharePreview("我的冲煮参数", image: renderImage())) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    @MainActor
    private func renderImage() -> Image {
        let renderer = ImageRenderer(content:
            ShareCard(bean: bean, brew: brew,
                      hideName: effHideName, showBranding: effBranding,
                      showFlavorTags: showFlavorTags,
                      showSubScores: showSubScores,
                      showGrinder: showGrinder,
                      showRoastInfo: showRoastInfo)
                .frame(width: 360, height: 495)
        )
        renderer.scale = 3
        if let ui = renderer.uiImage { return Image(uiImage: ui) }
        return Image(systemName: "cup.and.saucer.fill")
    }
}

// MARK: - 卡片视觉（自包含固定配色，便于离屏渲染）
struct ShareCard: View {
    let bean: Bean
    let brew: Brew
    var hideName: Bool = false
    var showBranding: Bool = true
    var showFlavorTags: Bool = true
    var showSubScores: Bool = false
    var showGrinder: Bool = false
    var showRoastInfo: Bool = false

    private let cream = Color(hex: 0xF3E9DB)
    private let creamDim = Color(hex: 0xC3B2A0)
    private let amber = Color(hex: 0xE0A03C)
    private let gold = Color(hex: 0xE6C25E)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x241710), Color(hex: 0x4A2E1B)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                // header
                VStack(alignment: .leading, spacing: 4) {
                    Text(hideName ? "我的一包豆子" : (bean.name.isEmpty ? "我的一包豆子" : bean.name))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(cream)
                        .lineLimit(1)
                    Text([bean.originText.isEmpty ? nil : bean.originText, bean.process.label, bean.roastLevel.label]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(creamDim)

                    if showFlavorTags, !bean.flavorTags.isEmpty {
                        Text(bean.flavorTags.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(amber)
                    }
                    if showRoastInfo, let d = bean.roastDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.system(size: 9))
                            Text("烘焙 \(d.formatted(.dateTime.month().day())) · 养豆 \(bean.restDays ?? 0) 天")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(creamDim.opacity(0.8))
                    }
                }

                Spacer(minLength: 0)

                // ring + score + sub-scores
                VStack(spacing: showSubScores ? 8 : 0) {
                    ZStack {
                        Circle().stroke(amber.opacity(0.2), lineWidth: 12)
                        Circle().trim(from: 0, to: min(1, (brew.overall ?? 0) / 5))
                            .stroke(gold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(NumFmt.score(brew.overall))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(cream)
                            Text("/ 5 分").font(.system(size: 11)).foregroundStyle(creamDim)
                        }
                    }
                    .frame(width: 130, height: 130)
                    .frame(maxWidth: .infinity)

                    if showSubScores {
                        HStack(spacing: 6) {
                            subScore("酸", brew.acidity)
                            subScore("甜", brew.sweetness)
                            subScore("醇", brew.bodyScore)
                            subScore("余", brew.aftertaste)
                            subScore("衡", brew.balance)
                        }
                    }
                }

                Spacer(minLength: 0)

                // params
                HStack(spacing: 0) {
                    param("研磨", NumFmt.g(brew.grind))
                    divider
                    param("粉量", "\(NumFmt.g(brew.dose))g")
                    divider
                    param("水温", brew.temp.map { "\(NumFmt.g($0))℃" } ?? "—")
                    divider
                    param("水量", "\(NumFmt.g(brew.water))g")
                    divider
                    param("粉水比", NumFmt.ratio(brew.ratio))
                    divider
                    param("时间", brew.totalTime > 0 ? TimeFmt.mmss(brew.totalTime) : "—")
                }
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                if showGrinder, !bean.grinderNote.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.2").font(.system(size: 10))
                        Text(bean.grinderNote)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(creamDim)
                    .padding(.top, 8)
                }

                if !brew.takeaway.isEmpty {
                    Text("「\(brew.takeaway)」")
                        .font(.system(size: 13, weight: .medium))
                        .italic()
                        .foregroundStyle(cream)
                        .padding(.top, 10)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if showBranding {
                    HStack {
                        Image(systemName: "drop.fill").font(.system(size: 10))
                        Text("CoffeeStory · 这包怎么冲").font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text("最佳参数").font(.system(size: 10)).foregroundStyle(gold)
                    }
                    .foregroundStyle(creamDim)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func subScore(_ label: String, _ value: Double?) -> some View {
        if let v = value, v > 0 {
            HStack(spacing: 2) {
                Text(label).font(.system(size: 9)).foregroundStyle(creamDim)
                Text(NumFmt.score(v))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(cream)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
    }

    private func param(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(cream)
            Text(title).font(.system(size: 9)).foregroundStyle(creamDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 20)
    }
}
