import SwiftUI
import SwiftData

enum ShelfSort: String, CaseIterable, Identifiable {
    case shouldBrew, recent, rest, name
    var id: String { rawValue }
    var label: String {
        switch self {
        case .shouldBrew: "该冲了"
        case .recent:     "最近添加"
        case .rest:       "养豆天数"
        case .name:       "名称"
        }
    }
}

struct ShelfView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(Entitlements.self) private var ent
    @Query private var beans: [Bean]
    @Query private var sessions: [ActiveBrewSession]

    @State private var sort: ShelfSort = .shouldBrew
    @State private var showNewBean = false
    @State private var showArchived = false
    @State private var pickingBean = false

    private var activeBeans: [Bean] {
        let list = beans.filter { !$0.archived }
        switch sort {
        case .shouldBrew: return list.sorted { $0.shouldBrewScore > $1.shouldBrewScore }
        case .recent:     return list.sorted { $0.createdAt > $1.createdAt }
        case .rest:       return list.sorted { ($0.restDays ?? -1) > ($1.restDays ?? -1) }
        case .name:       return list.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }
    private var archivedBeans: [Bean] {
        beans.filter { $0.archived }.sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    private var quickTarget: Bean? {
        activeBeans.sorted {
            ($0.latestBrew?.createdAt ?? .distantPast) > ($1.latestBrew?.createdAt ?? .distantPast)
        }.first
    }

    private var pendingSession: ActiveBrewSession? { sessions.first }
    private func bean(for session: ActiveBrewSession) -> Bean? {
        beans.first { $0.id == session.beanID }
    }

    private func addBean() {
        if !ent.isPro && activeBeans.count >= FreeLimits.maxActiveBeans {
            router.showPaywall = true
        } else {
            showNewBean = true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeBeans.isEmpty && archivedBeans.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .background(DT.canvas)
            .navigationTitle("豆架")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("排序", selection: $sort) {
                            ForEach(ShelfSort.allCases) { Text($0.label).tag($0) }
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addBean() } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: Bean.self) { BeanDetailView(bean: $0) }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showNewBean) { BeanEditorView() }
        }
    }

    // MARK: List
    private var listContent: some View {
        List {
            if let session = pendingSession, let b = bean(for: session) {
                resumeBar(session: session, bean: b)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Space.xl, bottom: 6, trailing: Space.xl))
            }
            ForEach(activeBeans) { bean in
                NavigationLink(value: bean) { BeanCardView(bean: bean) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Space.xl, bottom: 6, trailing: Space.xl))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { context.delete(bean) } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
            if !archivedBeans.isEmpty {
                Section {
                    if showArchived {
                        ForEach(archivedBeans) { bean in
                            NavigationLink(value: bean) { BeanCardView(bean: bean) }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: Space.xl, bottom: 6, trailing: Space.xl))
                        }
                    }
                } header: {
                    Button { withAnimation { showArchived.toggle() } } label: {
                        HStack {
                            Text("已喝完 (\(archivedBeans.count))")
                            Spacer()
                            Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DT.inkSecondary)
                    }
                    .textCase(nil)
                }
            }
            Color.clear.frame(height: 72).listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func resumeBar(session: ActiveBrewSession, bean: Bean) -> some View {
        Button { router.resume(session) } label: {
            HStack(spacing: Space.md) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(DT.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("继续上次冲煮").font(.subheadline.weight(.semibold)).foregroundStyle(DT.ink)
                    Text(bean.name).font(.caption).foregroundStyle(DT.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(DT.inkTertiary)
            }
            .padding(Space.md)
            .background(DT.amberSoft, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Bottom
    private var bottomBar: some View {
        Group {
            if let target = quickTarget {
                HStack(spacing: Space.md) {
                    Button {
                        router.startBrew(for: target, context: context, isPro: ent.isPro)
                    } label: {
                        HStack {
                            Image(systemName: "drop.fill")
                            VStack(alignment: .leading, spacing: 0) {
                                Text("冲一杯").font(.headline)
                                Text(target.name).font(.caption2).opacity(0.9)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .glassProminentButtonStyle()
                    .tint(DT.amber)

                    if activeBeans.count > 1 {
                        Menu {
                            ForEach(activeBeans) { b in
                                Button(b.name) { router.startBrew(for: b, context: context, isPro: ent.isPro) }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.headline)
                                .frame(width: 52, height: 52)
                        }
                        .glassButtonStyle()
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.sm)
            } else {
                Button { addBean() } label: {
                    Label("录入第一包豆子", systemImage: "plus")
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

    // MARK: Empty
    private var emptyState: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle().fill(DT.amberSoft).frame(width: 140, height: 140)
                Image(systemName: "bag.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(DT.amber)
            }
            Text("豆架还是空的")
                .font(.title2.weight(.bold))
                .foregroundStyle(DT.ink)
            Text("先把手头这包豆子加进来，\n开始记录它的调参历程。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(DT.inkSecondary)
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
