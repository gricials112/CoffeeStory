import SwiftUI
import SwiftData

struct BeanDetailView: View {
    @Bindable var bean: Bean
    @Environment(AppRouter.self) private var router
    @Environment(Entitlements.self) private var ent
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var axis: CurveAxis = .overall
    @State private var compareMode = false
    @State private var compareSelection: Set<UUID> = []
    @State private var showCalibrate = false
    @State private var editingBrew: Brew?
    @State private var showEditBean = false
    @State private var shareBrew: Brew?
    @State private var showGraduate = false

    private var ordered: [Brew] { bean.orderedBrews }
    private var attemptMap: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset + 1) })
    }
    private var timelineBrews: [Brew] {
        let best = bean.bestBrew
        let others = ordered.filter { $0.id != best?.id }.sorted { $0.createdAt > $1.createdAt }
        return (best.map { [$0] } ?? []) + others
    }
    private var selectedCompareBrews: [Brew] {
        ordered.filter { compareSelection.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                header
                if bean.brewCount > 0 {
                    curveSection
                    timelineSection
                } else {
                    emptyBrews
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(DT.canvas)
        .navigationTitle(bean.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditBean = true } label: { Label("编辑豆子", systemImage: "pencil") }
                    if let b = bean.bestBrew ?? bean.latestBrew {
                        Button { shareBrew = b } label: { Label("分享最佳", systemImage: "square.and.arrow.up") }
                    }
                    if !bean.archived {
                        Button { showGraduate = true } label: { Label("这包喝完了", systemImage: "checkmark.seal") }
                    }
                    Button(role: .destructive) {
                        context.delete(bean)
                        dismiss()
                    } label: { Label("删除豆子", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showCalibrate) { CalibrateSheet(bean: bean) }
        .sheet(isPresented: $showEditBean) { BeanEditorView(editing: bean) }
        .sheet(item: $editingBrew) { brew in BrewEditSheet(bean: bean, brew: brew) }
        .sheet(item: $shareBrew) { brew in ShareCardView(bean: bean, brew: brew, isPro: ent.isPro) }
        .sheet(isPresented: Binding(
            get: { !selectedCompareBrews.isEmpty && presentingCompare },
            set: { if !$0 { presentingCompare = false } })) {
                CompareView(brews: selectedCompareBrews, attemptMap: attemptMap)
        }
        .confirmationDialog("这包毕业啦 🎓", isPresented: $showGraduate, titleVisibility: .visible) {
            Button(bean.bestBrew == nil ? "毕业（未标记最佳）" : "存入配方并毕业") { graduate() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(bean.bestBrew == nil
                 ? "还没标记最佳参数，仍要毕业吗？"
                 : "把最佳配方存进配方库，并移到「已喝完」。")
        }
        .onAppear {
            axis = ordered.contains { $0.overall != nil } ? .overall : .grind
        }
    }

    @State private var presentingCompare = false

    // MARK: Header
    private var header: some View {
        VStack(spacing: Space.lg) {
            HStack(alignment: .top, spacing: Space.lg) {
                BeanCover(data: bean.coverImageData, size: 76)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        StatusBadge(status: bean.status)
                        if let d = bean.restDays {
                            HStack(spacing: 4) {
                                Circle().fill(bean.tasteStatus.color).frame(width: 7, height: 7)
                                Text("养豆 \(d) 天 · \(bean.tasteStatus.label)")
                                    .font(.caption).foregroundStyle(bean.tasteStatus.color)
                            }
                        }
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(metaChips, id: \.self) { tag in
                            Text(tag).font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(DT.surfaceSunken, in: Capsule())
                                .foregroundStyle(DT.inkSecondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Space.lg) {
                ZStack {
                    ExtractionRing(progress: bean.bagWeightGrams > 0 ? bean.remainingGrams / bean.bagWeightGrams : 0)
                    VStack(spacing: 0) {
                        Text(NumFmt.g(bean.remainingGrams))
                            .font(.roundedNumber(24, weight: .bold))
                            .foregroundStyle(DT.ink)
                        Text("g 剩余").font(.caption2).foregroundStyle(DT.inkTertiary)
                    }
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text("还能冲约 \(bean.estimatedCupsLeft()) 杯")
                        .font(.subheadline.weight(.medium)).foregroundStyle(DT.ink)
                    Text("已用 \(NumFmt.g(bean.bagWeightGrams - bean.remainingGrams)) / \(NumFmt.g(bean.bagWeightGrams)) g")
                        .font(.caption).foregroundStyle(DT.inkSecondary)
                    Button { showCalibrate = true } label: {
                        Label("校准剩余", systemImage: "scalemass")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(DT.amber)
                    .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
        }
        .surfaceCard()
    }

    private var metaChips: [String] {
        var c: [String] = []
        if !bean.originText.isEmpty { c.append(bean.originText) }
        c.append(bean.process.label)
        c.append(bean.roastLevel.label)
        c.append(contentsOf: bean.flavorTags.prefix(3))
        return c
    }

    // MARK: Curve
    private var curveSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("调参历程").font(.headline).foregroundStyle(DT.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CurveAxis.flavorAxes) { a in
                        axisChip(a)
                    }
                    Divider().frame(height: 18)
                    ForEach(CurveAxis.paramAxes) { a in
                        axisChip(a)
                    }
                }
            }
            ConvergenceChart(brews: ordered, axis: axis)
        }
        .surfaceCard()
    }

    private func axisChip(_ a: CurveAxis) -> some View {
        Button { withAnimation { axis = a }; Haptics.selection() } label: {
            Chip(text: a.label, selected: axis == a)
        }
        .buttonStyle(.plain)
    }

    // MARK: Timeline
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("每一次").font(.headline).foregroundStyle(DT.ink)
                Spacer()
                if bean.brewCount >= 2 {
                    Button {
                        if !compareMode && !ent.isPro {
                            router.showPaywall = true
                            return
                        }
                        withAnimation {
                            compareMode.toggle()
                            compareSelection.removeAll()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            if !ent.isPro && !compareMode {
                                Image(systemName: "lock.fill").font(.caption2)
                            }
                            Text(compareMode ? "取消" : "对比")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .tint(DT.amber)
                }
            }
            ForEach(timelineBrews) { brew in
                BrewTimelineCard(
                    brew: brew,
                    attempt: attemptMap[brew.id] ?? 0,
                    compareMode: compareMode,
                    selected: compareSelection.contains(brew.id),
                    onSetBest: { setBest(brew) },
                    onEdit: { editingBrew = brew },
                    onDelete: { delete(brew) },
                    onShare: { shareBrew = brew }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard compareMode else { return }
                    toggleCompare(brew)
                }
            }
        }
    }

    private var emptyBrews: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44)).foregroundStyle(DT.amber.opacity(0.6))
            Text("还没有数据").font(.headline).foregroundStyle(DT.ink)
            Text("来冲第一杯，开启这包的收敛曲线。")
                .font(.subheadline).foregroundStyle(DT.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
        .surfaceCard()
    }

    // MARK: Bottom
    private var bottomBar: some View {
        Group {
            if compareMode {
                HStack {
                    Text("已选 \(compareSelection.count) / 3")
                        .font(.subheadline).foregroundStyle(DT.inkSecondary)
                    Spacer()
                    Button {
                        presentingCompare = true
                    } label: {
                        Text("开始对比").font(.headline).padding(.horizontal, Space.lg).padding(.vertical, 4)
                    }
                    .glassProminentButtonStyle()
                    .tint(DT.amber)
                    .disabled(compareSelection.count < 2)
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.sm)
            } else if !bean.archived {
                Button {
                    router.startBrew(for: bean, context: context, isPro: ent.isPro)
                } label: {
                    Label(bean.brewCount == 0 ? "冲第一杯" : "再冲一次", systemImage: "drop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .glassProminentButtonStyle()
                .tint(DT.amber)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.sm)
            }
        }
    }

    // MARK: Actions
    private func setBest(_ brew: Brew) {
        for b in bean.brews { b.isBest = false }
        brew.isBest = true
        Haptics.success()
    }
    private func toggleCompare(_ brew: Brew) {
        if compareSelection.contains(brew.id) {
            compareSelection.remove(brew.id)
        } else if compareSelection.count < 3 {
            compareSelection.insert(brew.id)
            Haptics.selection()
        }
    }
    private func delete(_ brew: Brew) {
        bean.remainingGrams = min(bean.bagWeightGrams, bean.remainingGrams + brew.dose)
        context.delete(brew)
    }
    private func graduate() {
        if let best = bean.bestBrew {
            let r = RecipeArchive()
            r.sourceBeanName = bean.name
            r.originText = bean.originText
            r.processRaw = bean.process.rawValue
            r.roastLevelRaw = bean.roastLevel.rawValue
            r.flavorTags = bean.flavorTags
            r.grind = best.grind
            r.dose = best.dose
            r.water = best.water
            r.temp = best.temp
            r.totalTime = best.totalTime
            r.pours = best.pours
            r.overall = best.overall
            r.takeaway = best.takeaway
            context.insert(r)
        }
        bean.archived = true
        bean.archivedAt = Date()
        Haptics.success()
        dismiss()
    }
}
