import SwiftUI
import SwiftData

struct RecipesView: View {
    @Query(sort: \RecipeArchive.createdAt, order: .reverse) private var recipes: [RecipeArchive]
    @State private var filterProcess: Process?
    @State private var filterRoast: RoastLevel?

    private var filtered: [RecipeArchive] {
        recipes.filter {
            (filterProcess == nil || $0.process == filterProcess) &&
            (filterRoast == nil || $0.roastLevel == filterRoast)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(filtered) { recipe in
                            NavigationLink(value: recipe) { RecipeCard(recipe: recipe) }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: Space.xl, bottom: 6, trailing: Space.xl))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DT.canvas)
            .navigationTitle("配方库")
            .navigationDestination(for: RecipeArchive.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                if !recipes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("处理法", selection: $filterProcess) {
                                Text("全部处理法").tag(Process?.none)
                                ForEach(Process.allCases) { Text($0.label).tag(Process?.some($0)) }
                            }
                            Picker("烘焙度", selection: $filterRoast) {
                                Text("全部烘焙度").tag(RoastLevel?.none)
                                ForEach(RoastLevel.allCases) { Text($0.label).tag(RoastLevel?.some($0)) }
                            }
                        } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: Space.lg) {
            ZStack {
                Circle().fill(DT.amberSoft).frame(width: 140, height: 140)
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 52)).foregroundStyle(DT.amber)
            }
            Text("还没有沉淀的配方").font(.title2.weight(.bold)).foregroundStyle(DT.ink)
            Text("调出一包的最佳参数、让它毕业，\n配方就会归档到这里，供下次复用。")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(DT.inkSecondary)
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RecipeCard: View {
    let recipe: RecipeArchive
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text(recipe.sourceBeanName.isEmpty ? "未命名配方" : recipe.sourceBeanName)
                    .font(.headline).foregroundStyle(DT.ink)
                Spacer()
                if let o = recipe.overall {
                    Label(NumFmt.score(o), systemImage: "star.fill")
                        .font(.footnote.weight(.semibold)).foregroundStyle(DT.gold)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach([recipe.originText.isEmpty ? nil : recipe.originText,
                         recipe.process.label, recipe.roastLevel.label].compactMap { $0 }, id: \.self) { t in
                    Text(t).font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(DT.surfaceSunken, in: Capsule())
                        .foregroundStyle(DT.inkSecondary)
                }
            }
            HStack(spacing: Space.lg) {
                miniParam("研磨", NumFmt.g(recipe.grind))
                miniParam("粉水比", NumFmt.ratio(recipe.ratio))
                if let t = recipe.temp { miniParam("水温", "\(NumFmt.g(t))℃") }
            }
        }
        .surfaceCard()
    }
    private func miniParam(_ t: String, _ v: String) -> some View {
        HStack(spacing: 3) {
            Text(t).font(.caption2).foregroundStyle(DT.inkTertiary)
            Text(v).font(.caption.monospacedDigit().weight(.medium)).foregroundStyle(DT.inkSecondary)
        }
    }
}
