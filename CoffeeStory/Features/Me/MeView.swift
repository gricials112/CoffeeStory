import SwiftUI
import SwiftData

struct MeView: View {
    @Query private var beans: [Bean]
    @Environment(Entitlements.self) private var ent
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var exportFile: ExportService.ExportFile?

    private var allBrews: [Brew] { beans.flatMap(\.brews) }
    private var activeCount: Int { beans.filter { !$0.archived }.count }
    private var archivedCount: Int { beans.filter { $0.archived }.count }
    private var avgScore: Double? {
        let scored = allBrews.compactMap(\.overall)
        guard !scored.isEmpty else { return nil }
        return scored.reduce(0, +) / Double(scored.count)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        proCard
                        HStack(spacing: Space.md) {
                            statCard("累计冲煮", "\(allBrews.count)", "杯", "drop.fill", DT.amber)
                            statCard("在架", "\(activeCount)", "包", "bag.fill", DT.coffee)
                        }
                        HStack(spacing: Space.md) {
                            statCard("已喝完", "\(archivedCount)", "包", "checkmark.seal.fill", DT.peak)
                            statCard("平均分", avgScore.map { NumFmt.score($0) } ?? "—", "分", "star.fill", DT.gold)
                        }

                        NavigationLink {
                            SettingsView()
                        } label: {
                            rowCard("设置", systemImage: "gearshape.fill", trailing: "chevron.right")
                        }
                        .buttonStyle(.plain)

                        Button {
                            if !ent.isPro { router.showPaywall = true; return }
                            exportFile = ExportService.writeTempFile(beans: beans)
                        } label: {
                            rowCard("导出数据 (JSON)",
                                    systemImage: ent.isPro ? "tray.and.arrow.down.fill" : "lock.fill",
                                    trailing: ent.isPro ? nil : "Pro")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Space.xl)
                    .padding(.vertical, Space.lg)
                }
                .frame(maxWidth: .infinity)
                .background(DT.canvas)

                #if DEBUG
                HStack(spacing: 8) {
                    debugSeedButton
                    debugProToggle
                }
                .padding([.trailing, .bottom], 8)
                #endif
            }
            .navigationTitle("我的")
            .sheet(item: $exportFile) { f in ActivityView(items: [f.url]) }
        }
    }

    #if DEBUG
    private var debugSeedButton: some View {
        Button {
            seedMockData()
            Haptics.success()
        } label: {
            Label("注入Mock", systemImage: "flask.fill")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DT.amber)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }

    private func seedMockData() {
        let b = Bean(name: "埃塞俄比亚 古吉 罕贝拉")
        b.roaster = "有容乃大"
        b.originText = "埃塞俄比亚 古吉 罕贝拉"
        b.process = .natural
        b.roastLevel = .light
        b.roastDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())
        b.flavorTags = ["草莓", "荔枝", "玫瑰", "红茶"]
        b.notes = "这款豆子果酸非常明亮，高温时草莓香气很突出，降温后荔枝甜感逐渐展现，推荐养豆7天后开冲。"
        b.grinderNote = "C40 · 24格"
        modelContext.insert(b)

        let brew = Brew(grind: 24, dose: 15, water: 240, temp: 93)
        brew.totalTime = 148
        brew.overall = 4.3
        brew.acidity = 4.5; brew.sweetness = 4.2; brew.bodyScore = 3.5
        brew.aftertaste = 4.0; brew.balance = 4.3
        brew.pours = [
            PourStage(label: "闷蒸", targetWaterCumulative: 30, targetTime: 30, actualAt: 32),
            PourStage(label: "第一段", targetWaterCumulative: 100, targetTime: 55, actualAt: 56),
            PourStage(label: "第二段", targetWaterCumulative: 170, targetTime: 85, actualAt: 88),
            PourStage(label: "第三段", targetWaterCumulative: 240, targetTime: 120, actualAt: 122),
        ]
        brew.takeaway = "高温草莓香很惊艳，甜感持久"
        brew.nextTweaks = [
            NextTweak(dimension: .grind, direction: .finer),
            NextTweak(dimension: .temp, direction: .down),
        ]
        brew.nextTweakNote = "调细一格试试能不能带出更多花香"
        brew.bean = b
        modelContext.insert(brew)

        try? modelContext.save()
    }

    private var debugProToggle: some View {
        Button {
            ent.isPro.toggle()
            Haptics.success()
        } label: {
            Label(ent.isPro ? "Pro ON" : "Pro OFF",
                  systemImage: ent.isPro ? "crown.fill" : "crown")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ent.isPro ? DT.gold : DT.inkTertiary.opacity(0.3))
                .foregroundStyle(ent.isPro ? .white : DT.inkSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    #endif

    private var proCard: some View {
        Group {
            if ent.isPro {
                HStack(spacing: Space.md) {
                    Image(systemName: "crown.fill").font(.title2).foregroundStyle(DT.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brew Pro 已解锁").font(.headline).foregroundStyle(DT.ink)
                        Text("感谢支持，尽情榨干每一包豆子 ☕️").font(.caption).foregroundStyle(DT.inkSecondary)
                    }
                    Spacer()
                }
                .surfaceCard(tint: DT.goldSoft.opacity(0.5))
            } else {
                Button { router.showPaywall = true } label: {
                    HStack(spacing: Space.md) {
                        Image(systemName: "crown.fill").font(.title2).foregroundStyle(DT.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("升级 Brew Pro").font(.headline).foregroundStyle(DT.ink)
                            Text("无限记录 · 对比 · 配方库 · 去水印").font(.caption).foregroundStyle(DT.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(DT.inkTertiary)
                    }
                    .surfaceCard(tint: DT.goldSoft.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rowCard(_ title: String, systemImage: String, trailing: String?) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline).foregroundStyle(DT.ink)
            Spacer()
            if let trailing {
                if trailing == "chevron.right" {
                    Image(systemName: "chevron.right").foregroundStyle(DT.inkTertiary)
                } else {
                    Text(trailing).font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(DT.goldSoft, in: Capsule())
                        .foregroundStyle(DT.gold)
                }
            }
        }
        .surfaceCard()
    }

    private func statCard(_ title: String, _ value: String, _ unit: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.roundedNumber(28, weight: .bold)).foregroundStyle(DT.ink)
                Text(unit).font(.caption).foregroundStyle(DT.inkTertiary)
            }
            Text(title).font(.caption).foregroundStyle(DT.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @AppStorage(SettingsKey.defaultRatio) private var defaultRatio = 16.0
    @AppStorage(SettingsKey.keepScreenOn) private var keepScreenOn = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplate = PourTemplate.three.rawValue
    @AppStorage(SettingsKey.colorScheme) private var colorScheme = "system"

    private let privacyURL = URL(string: "https://gricials112.github.io/CoffeeStory/privacy-policy.html")!

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("冲煮默认") {
                Stepper(value: $defaultRatio, in: 10...20, step: 0.5) {
                    HStack {
                        Text("默认粉水比")
                        Spacer()
                        Text(NumFmt.ratio(defaultRatio)).foregroundStyle(DT.amber).monospacedDigit()
                    }
                }
                Picker("默认分段模板", selection: $defaultTemplate) {
                    ForEach(PourTemplate.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }
            Section("计时器") {
                Toggle("冲煮时屏幕常亮", isOn: $keepScreenOn)
                Toggle("触感反馈", isOn: $haptics)
            }
            Section("外观") {
                Picker("主题", selection: $colorScheme) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("关于") {
                HStack { Text("版本"); Spacer(); Text(versionString).foregroundStyle(DT.inkTertiary) }
                HStack { Text("理念"); Spacer(); Text("这包豆子，越冲越好").foregroundStyle(DT.inkTertiary) }
                Link(destination: privacyURL) {
                    HStack {
                        Text("隐私政策")
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(DT.inkTertiary)
                    }
                }
                .tint(DT.ink)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DT.amber)
    }
}
