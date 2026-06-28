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
    @AppStorage(SettingsKey.shareShowPours)      private var showPours      = true
    @AppStorage(SettingsKey.shareShowNextTweaks) private var showNextTweaks = true
    @AppStorage(SettingsKey.shareShowBeanNotes)  private var showBeanNotes   = true
    @AppStorage(SettingsKey.shareShowBgImage)    private var showBgImage     = true
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
                              showRoastInfo: showRoastInfo,
                              showPours: showPours,
                              showNextTweaks: showNextTweaks,
                              showBeanNotes: showBeanNotes,
                              showBgImage: showBgImage)
                        .frame(width: 320)
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
                            .disabled(bean.grinderNote.isEmpty)
                        Toggle("烘焙信息", isOn: $showRoastInfo)
                            .disabled(bean.roastDate == nil)
                        Toggle("注水分段", isOn: $showPours)
                            .disabled(brew.pours.isEmpty)
                        Toggle("下次调整", isOn: $showNextTweaks)
                            .disabled(brew.nextTweaks.isEmpty && brew.nextTweakNote.isEmpty)
                        Toggle("豆子备注", isOn: $showBeanNotes)
                            .disabled(bean.notes.isEmpty)
                        Toggle("背景图片", isOn: $showBgImage)

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
        let card = ShareCard(bean: bean, brew: brew,
                             hideName: effHideName, showBranding: effBranding,
                             showFlavorTags: showFlavorTags,
                             showSubScores: showSubScores,
                             showGrinder: showGrinder,
                             showRoastInfo: showRoastInfo,
                             showPours: showPours,
                             showNextTweaks: showNextTweaks,
                             showBeanNotes: showBeanNotes,
                             showBgImage: showBgImage)
            .frame(width: 360)
        let renderer = ImageRenderer(content: card.fixedSize(horizontal: false, vertical: true))
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
    var showPours: Bool = true
    var showNextTweaks: Bool = true
    var showBeanNotes: Bool = true
    var showBgImage: Bool = true

    private let cream = Color(hex: 0xF3E9DB)
    private let creamDim = Color(hex: 0xC3B2A0)
    private let amber = Color(hex: 0xE0A03C)
    private let gold = Color(hex: 0xE6C25E)

    private var displayName: String {
        if hideName { return "我的一包豆子" }
        return bean.name.isEmpty ? "我的一包豆子" : bean.name
    }

    private var originLine: String {
        [bean.originText.isEmpty ? nil : bean.originText,
         bean.process.label,
         bean.roastLevel.label].compactMap { $0 }.joined(separator: " · ")
    }

    private var hasTweaks: Bool {
        !brew.nextTweaks.isEmpty || !brew.nextTweakNote.isEmpty
    }

    var body: some View {
        ZStack {
            // 背景（图片 或 纯色渐变）
            if showBgImage {
                Color.clear
                    .overlay(
                        Image("ShareBackground")
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
            }
            LinearGradient(colors: [
                Color(hex: 0x241710).opacity(showBgImage ? 0.70 : 1.0),
                Color(hex: 0x4A2E1B).opacity(showBgImage ? 0.60 : 1.0)
            ], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                // ───── Header ─────
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(cream)
                        .lineLimit(1)

                    if !bean.roaster.isEmpty {
                        Text(bean.roaster)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(gold)
                    }

                    if !originLine.isEmpty {
                        Text(originLine)
                            .font(.system(size: 12))
                            .foregroundStyle(creamDim)
                    }

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
                .padding(.bottom, 14)

                // ───── Score ─────
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
                .padding(.bottom, 14)

                // ───── Params ─────
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

                // ───── Pour Stages ─────
                if showPours, !brew.pours.isEmpty {
                    sectionDivider("注水")
                        .padding(.top, 14)
                    VStack(spacing: 6) {
                        ForEach(brew.pours) { stage in
                            pourRow(stage)
                        }
                    }
                    .padding(.top, 8)
                }

                // ───── Next Tweaks ─────
                if showNextTweaks, hasTweaks {
                    sectionDivider("下次调整")
                        .padding(.top, 14)
                    if !brew.nextTweaks.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(brew.nextTweaks) { tweak in
                                Text(tweak.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(amber)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 6)
                    }
                    if !brew.nextTweakNote.isEmpty {
                        Text(brew.nextTweakNote)
                            .font(.system(size: 11))
                            .foregroundStyle(creamDim)
                            .padding(.top, brew.nextTweaks.isEmpty ? 6 : 2)
                    }
                }

                // ───── Bean Notes ─────
                if showBeanNotes, !bean.notes.isEmpty {
                    Text(bean.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(creamDim)
                        .lineLimit(3)
                        .padding(.top, 12)
                }

                // ───── Grinder ─────
                if showGrinder, !bean.grinderNote.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.2").font(.system(size: 10))
                        Text(bean.grinderNote)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(creamDim)
                    .padding(.top, 10)
                }

                // ───── Takeaway ─────
                if !brew.takeaway.isEmpty {
                    Text("「\(brew.takeaway)」")
                        .font(.system(size: 13, weight: .medium))
                        .italic()
                        .foregroundStyle(cream)
                        .padding(.top, 10)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                // ───── Branding ─────
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

    // MARK: - Sub-views

    @ViewBuilder
    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(creamDim.opacity(0.3)).frame(height: 1)
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(creamDim)
            Rectangle().fill(creamDim.opacity(0.3)).frame(height: 1)
        }
    }

    @ViewBuilder
    private func pourRow(_ stage: PourStage) -> some View {
        HStack {
            Text(stage.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(cream)
            Spacer()
            Text("\(NumFmt.g(stage.targetWaterCumulative))g")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(cream)
            if let t = stage.actualAt ?? stage.targetTime {
                Text("· \(TimeFmt.mmss(t))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(creamDim)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
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
