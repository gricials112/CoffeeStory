import SwiftUI

// MARK: - 模板选择
enum TemplateChoice: Equatable {
    case builtIn(PourTemplate)
    case saved(SavedPourTemplate)
    case freeform

    var id: String {
        switch self {
        case .builtIn(let t): t.rawValue
        case .saved(let s):   s.id.uuidString
        case .freeform:       "freeform"
        }
    }

    var label: String {
        switch self {
        case .builtIn(let t): t.label
        case .saved(let s):   s.name
        case .freeform:       "自定义"
        }
    }
}

struct PrepareView: View {
    let controller: BrewFlowController
    @Bindable var session: ActiveBrewSession
    @AppStorage(SettingsKey.pourCumulative) private var cumulative = true
    @State private var selectedTemplate: TemplateChoice?
    @State private var savedTemplates: [SavedPourTemplate] = []
    @State private var showSaveDialog = false
    @State private var newTemplateName = ""
    @State private var hiddenBuiltInIDs: [String] = []

    private var visibleBuiltInTemplates: [PourTemplate] {
        PourTemplate.allCases.filter { !hiddenBuiltInIDs.contains($0.rawValue) }
    }

    private var hasHiddenDefaults: Bool { !hiddenBuiltInIDs.isEmpty }

    private var tempBinding: Binding<Double> {
        Binding(get: { session.temp ?? 92 }, set: { session.temp = $0 })
    }
    private var doseBinding: Binding<Double> {
        Binding(get: { session.dose }, set: { controller.setDose($0) })
    }
    private var waterBinding: Binding<Double> {
        Binding(get: { session.water }, set: { controller.setWater($0) })
    }
    private var grindBinding: Binding<Double> {
        Binding(get: { session.grind }, set: { session.grind = $0 })
    }

    private var hint: [NextTweak] {
        guard controller.bean.status != .dialedIn else { return [] }
        return controller.bean.latestBrew?.nextTweaks ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                if !hint.isEmpty {
                    HStack(alignment: .top, spacing: Space.sm) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(DT.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("上次说要调").font(.caption.weight(.semibold)).foregroundStyle(DT.coffee)
                            Text(hint.map(\.label).joined(separator: "、"))
                                .font(.subheadline).foregroundStyle(DT.ink)
                            if let note = controller.bean.latestBrew?.nextTweakNote, !note.isEmpty {
                                Text(note).font(.caption).foregroundStyle(DT.inkSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(Space.md)
                    .background(DT.amberSoft, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }

                // 参数
                VStack(spacing: Space.md) {
                    StepperField(title: "研磨度", value: grindBinding, range: 0...100, step: 0.5)
                    if !controller.bean.grinderNote.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "dial.medium").font(.caption2)
                            Text(controller.bean.grinderNote)
                        }
                        .font(.caption2).foregroundStyle(DT.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: Space.sm) {
                        StepperField(title: "粉量", unit: "g", value: doseBinding, range: 1...200, step: 0.5, compact: true)
                        StepperField(title: "水量", unit: "g", value: waterBinding, range: 1...3000, step: 5, compact: true)
                    }
                    HStack {
                        Text("粉水比").font(.footnote).foregroundStyle(DT.inkSecondary)
                        Text(NumFmt.ratio(controller.ratio))
                            .font(.roundedNumber(16, weight: .bold)).foregroundStyle(DT.amber)
                        Spacer()
                        ForEach([15.0, 16.0, 17.0], id: \.self) { r in
                            Button { controller.setRatio(r) } label: {
                                Chip(text: "1:\(Int(r))", selected: abs(controller.ratio - r) < 0.05)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    StepperField(title: "水温", unit: "℃", value: tempBinding, range: 60...100, step: 1)
                }
                .surfaceCard()

                // 注水模板
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack {
                        Text("注水分段").font(.headline).foregroundStyle(DT.ink)
                        Spacer()
                        if isInFreeform && !session.pours.isEmpty {
                            Button {
                                newTemplateName = ""
                                showSaveDialog = true
                            } label: {
                                Label("保存模板", systemImage: "bookmark").font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DT.amber)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(visibleBuiltInTemplates) { t in
                                let choice = TemplateChoice.builtIn(t)
                                Button {
                                    selectedTemplate = choice
                                    controller.applyTemplate(t)
                                } label: {
                                    Chip(text: choice.label, selected: selectedTemplate == choice)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        hideBuiltInTemplate(t)
                                    } label: {
                                        Label("隐藏", systemImage: "eye.slash")
                                    }
                                }
                            }
                            if hasHiddenDefaults {
                                Button {
                                    restoreAllDefaults()
                                } label: {
                                    Chip(text: "恢复默认", selected: false)
                                }
                                .buttonStyle(.plain)
                            }
                            if !savedTemplates.isEmpty {
                                Divider().frame(height: 20)
                            }
                            ForEach(savedTemplates) { saved in
                                let choice = TemplateChoice.saved(saved)
                                Button {
                                    selectedTemplate = choice
                                    controller.setCustomPours(saved.stages)
                                } label: {
                                    Chip(text: saved.name, selected: selectedTemplate == choice)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        PourTemplateStorage.delete(saved.id)
                                        savedTemplates = PourTemplateStorage.load()
                                        if selectedTemplate == choice {
                                            selectedTemplate = .freeform
                                        }
                                    } label: {
                                        Label("删除模板", systemImage: "trash")
                                    }
                                }
                            }
                            Divider().frame(height: 20)
                            Button {
                                selectedTemplate = .freeform
                                if session.pours.isEmpty {
                                    controller.setCustomPours(PourTemplate.single.stages(dose: session.dose, water: session.water))
                                }
                            } label: {
                                Chip(text: "自定义", selected: selectedTemplate == .freeform)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(isInFreeform
                        ? "自定义模式下可以编辑阶段名称、水量和每段用时，编辑后点「保存模板」加入推荐列表。"
                        : "套用模板后直接修改任意阶段，会自动切换为自定义。")
                        .font(.caption)
                        .foregroundStyle(DT.inkTertiary)
                    Toggle(isOn: $cumulative) {
                        Text("水量按累计显示").font(.caption).foregroundStyle(DT.inkSecondary)
                    }
                    .tint(DT.amber)
                    PourPlanEditor(
                        stages: session.pours,
                        cumulative: cumulative,
                        onUpdate: { stages in
                            selectedTemplate = .freeform
                            controller.setCustomPours(stages)
                        }
                    )
                }
                .surfaceCard()
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .onAppear {
            loadHiddenTemplates()
            savedTemplates = PourTemplateStorage.load()
            if let match = PourTemplate.matching(stages: session.pours, dose: session.dose, water: session.water) {
                selectedTemplate = .builtIn(match)
            } else if let saved = savedTemplates.first(where: { $0.stages == session.pours }) {
                selectedTemplate = .saved(saved)
            } else if !session.pours.isEmpty {
                selectedTemplate = .freeform
            }
        }
        .alert("保存为模板", isPresented: $showSaveDialog) {
            TextField("模板名称（如 V60四段）", text: $newTemplateName)
            Button("保存") { saveCurrentAsTemplate() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("输入名称后，该分段方案将出现在推荐列表中。")
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { controller.startTimer() }
            } label: {
                Label("开始计时", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .glassProminentButtonStyle()
            .tint(DT.amber)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.sm)
        }
    }

    private var isInFreeform: Bool {
        if case .freeform = selectedTemplate { true } else { false }
    }

    private func saveCurrentAsTemplate() {
        let name = newTemplateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !session.pours.isEmpty else { return }
        PourTemplateStorage.add(name: name, stages: session.pours)
        savedTemplates = PourTemplateStorage.load()
        if let saved = savedTemplates.last(where: { $0.name == name }) {
            selectedTemplate = .saved(saved)
        }
    }

    // MARK: - 隐藏/恢复默认模板
    private func loadHiddenTemplates() {
        guard let data = UserDefaults.standard.data(forKey: "hiddenBuiltInTemplates"),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { hiddenBuiltInIDs = []; return }
        hiddenBuiltInIDs = ids
    }

    private func saveHiddenTemplates() {
        guard let data = try? JSONEncoder().encode(hiddenBuiltInIDs) else { return }
        UserDefaults.standard.set(data, forKey: "hiddenBuiltInTemplates")
    }

    private func hideBuiltInTemplate(_ t: PourTemplate) {
        if selectedTemplate == .builtIn(t) {
            selectedTemplate = .freeform
        }
        hiddenBuiltInIDs.append(t.rawValue)
        saveHiddenTemplates()
    }

    private func restoreAllDefaults() {
        hiddenBuiltInIDs = []
        selectedTemplate = .freeform
        saveHiddenTemplates()
    }
}

// MARK: - 分段计划编辑
struct PourPlanEditor: View {
    let stages: [PourStage]
    var cumulative: Bool
    var onUpdate: ([PourStage]) -> Void

    private func labelBinding(for idx: Int) -> Binding<String> {
        Binding(
            get: { stages[safe: idx]?.label ?? "" },
            set: { newValue in
                updateStage(at: idx) { $0.label = newValue }
            }
        )
    }

    private func waterBinding(for idx: Int) -> Binding<Double> {
        Binding(
            get: { waterShown(at: idx) },
            set: { setWater($0, at: idx) }
        )
    }

    private func durationBinding(for idx: Int) -> Binding<Double> {
        Binding(
            get: { durationShown(at: idx) },
            set: { setDuration($0, at: idx) }
        )
    }

    private func stageDisplayName(_ stage: PourStage, at idx: Int) -> String {
        let label = stage.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? "阶段 \(idx + 1)" : label
    }

    private func previousWater(before idx: Int) -> Double {
        idx > 0 ? (stages[safe: idx - 1]?.targetWaterCumulative ?? 0) : 0
    }

    private func waterShown(at idx: Int) -> Double {
        guard let stage = stages[safe: idx] else { return 0 }
        if cumulative { return stage.targetWaterCumulative }
        return max(0, stage.targetWaterCumulative - previousWater(before: idx))
    }

    private func previousTime(before idx: Int, in source: [PourStage]? = nil) -> TimeInterval {
        let list = source ?? stages
        return idx > 0 ? (list[safe: idx - 1]?.targetTime ?? 0) : 0
    }

    private func durationShown(at idx: Int) -> TimeInterval {
        guard let stage = stages[safe: idx] else { return 0 }
        let end = stage.targetTime ?? previousTime(before: idx) + (idx == 0 ? 30 : 60)
        return max(0, end - previousTime(before: idx))
    }

    private func withFilledTimes(_ source: [PourStage]) -> [PourStage] {
        var next = source
        var previous: TimeInterval = 0
        for idx in next.indices {
            if next[idx].targetTime == nil {
                next[idx].targetTime = previous + (idx == 0 ? 30 : 60)
            }
            previous = next[idx].targetTime ?? previous
        }
        return next
    }

    private func updateStage(at idx: Int, mutate: (inout PourStage) -> Void) {
        guard stages.indices.contains(idx) else { return }
        var next = stages
        mutate(&next[idx])
        onUpdate(next)
    }

    private func setWater(_ value: Double, at idx: Int) {
        guard stages.indices.contains(idx) else { return }
        var next = stages
        if cumulative {
            next[idx].targetWaterCumulative = value
            onUpdate(next)
            return
        }
        let oldCumulative = next[idx].targetWaterCumulative
        let newCumulative = previousWater(before: idx) + value
        let delta = newCumulative - oldCumulative
        for i in idx..<next.count {
            next[i].targetWaterCumulative += delta
        }
        onUpdate(next)
    }

    private func setDuration(_ value: Double, at idx: Int) {
        guard stages.indices.contains(idx) else { return }
        var next = withFilledTimes(stages)
        let oldEnd = next[idx].targetTime ?? previousTime(before: idx, in: next)
        let newEnd = previousTime(before: idx, in: next) + value
        let delta = newEnd - oldEnd
        for i in idx..<next.count {
            next[i].targetTime = (next[i].targetTime ?? oldEnd) + delta
        }
        onUpdate(next)
    }

    private func addStage() {
        var next = withFilledTimes(stages)
        guard !next.isEmpty else {
            onUpdate([PourStage(label: "注水", targetWaterCumulative: 120, targetTime: 90)])
            return
        }

        if next.count == 1 {
            let final = next[0]
            let finalTime = final.targetTime ?? 150
            let first = PourStage(
                label: "阶段 1",
                targetWaterCumulative: max(1, (final.targetWaterCumulative / 2).rounded()),
                targetTime: max(5, (finalTime / 2).rounded())
            )
            var second = final
            if second.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                second.label = "阶段 2"
            }
            onUpdate([first, second])
            return
        }

        let insertIndex = next.count - 1
        let prevWater = insertIndex > 0 ? next[insertIndex - 1].targetWaterCumulative : 0
        let final = next[insertIndex]
        let prevTime = insertIndex > 0 ? (next[insertIndex - 1].targetTime ?? 0) : 0
        let finalTime = final.targetTime ?? prevTime + 60
        let inserted = PourStage(
            label: "阶段 \(insertIndex + 1)",
            targetWaterCumulative: ((prevWater + final.targetWaterCumulative) / 2).rounded(),
            targetTime: ((prevTime + finalTime) / 2).rounded()
        )
        next.insert(inserted, at: insertIndex)
        onUpdate(next)
    }

    private func deleteStage(at idx: Int) {
        guard stages.count > 1, stages.indices.contains(idx) else { return }
        var next = withFilledTimes(stages)
        let removed = next.remove(at: idx)
        if idx >= next.count, let last = next.indices.last {
            next[last].targetWaterCumulative = removed.targetWaterCumulative
            next[last].targetTime = removed.targetTime
        }
        onUpdate(next)
    }

    var body: some View {
        VStack(spacing: Space.sm) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { idx, stage in
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        Text("第 \(idx + 1) 段")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DT.inkSecondary)
                        Spacer()
                        if stages.count > 1 {
                            Button(role: .destructive) { deleteStage(at: idx) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(DT.past)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("阶段名称", text: labelBinding(for: idx))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DT.ink)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, 10)
                        .background(DT.surface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .accessibilityLabel("第 \(idx + 1) 段名称")

                    HStack(spacing: Space.sm) {
                        StepperField(
                            title: cumulative ? "累计水量" : "本段水量",
                            unit: "g",
                            value: waterBinding(for: idx),
                            range: 1...3000,
                            step: 5,
                            compact: true
                        )
                        StepperField(
                            title: "用时",
                            value: durationBinding(for: idx),
                            range: 5...3600,
                            step: 5,
                            format: { TimeFmt.mmss($0) },
                            parse: TimeFmt.parse,
                            compact: true
                        )
                    }

                    HStack(spacing: 4) {
                        Text(stageDisplayName(stage, at: idx))
                        Text("到 \(NumFmt.g(stage.targetWaterCumulative))g")
                        if let targetTime = stage.targetTime {
                            Text("· \(TimeFmt.mmss(targetTime)) 完成")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(DT.inkTertiary)
                }
                .padding(Space.sm)
                .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }

            Button(action: addStage) {
                Label("新增阶段", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DT.amber)
            .background(DT.amberSoft, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
    }
}
