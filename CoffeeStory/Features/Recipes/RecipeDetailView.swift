import SwiftUI

struct RecipeDetailView: View {
    let recipe: RecipeArchive
    @Environment(Entitlements.self) private var ent
    @Environment(AppRouter.self) private var router
    @State private var showNewBean = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: Space.md) {
                    HStack {
                        ForEach([("研磨", NumFmt.g(recipe.grind)),
                                 ("粉量", "\(NumFmt.g(recipe.dose))g"),
                                 ("水量", "\(NumFmt.g(recipe.water))g")], id: \.0) { stat($0.0, $0.1) }
                    }
                    HStack {
                        stat("粉水比", NumFmt.ratio(recipe.ratio))
                        stat("水温", recipe.temp.map { "\(NumFmt.g($0))℃" } ?? "—")
                        stat("总时间", recipe.totalTime > 0 ? TimeFmt.mmss(recipe.totalTime) : "—")
                    }
                }
                .surfaceCard()

                if !recipe.pours.isEmpty {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("注水分段").font(.headline).foregroundStyle(DT.ink)
                        ForEach(recipe.pours) { stage in
                            HStack {
                                Text(stage.label).font(.subheadline).foregroundStyle(DT.ink)
                                Spacer()
                                Text("\(NumFmt.g(stage.targetWaterCumulative))g")
                                    .font(.caption.monospacedDigit()).foregroundStyle(DT.inkSecondary)
                                if let t = stage.targetTime {
                                    Text("@ \(TimeFmt.mmss(t))").font(.caption.monospacedDigit())
                                        .foregroundStyle(DT.inkTertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .surfaceCard()
                }

                if !recipe.takeaway.isEmpty {
                    Text("「\(recipe.takeaway)」")
                        .font(.body).italic().foregroundStyle(DT.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .surfaceCard()
                }

                Text("来自：\(recipe.sourceBeanName.isEmpty ? "未命名" : recipe.sourceBeanName)")
                    .font(.caption).foregroundStyle(DT.inkTertiary)
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
            .padding(.bottom, 80)
        }
        .background(DT.canvas)
        .navigationTitle("配方")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                if ent.isPro { showNewBean = true } else { router.showPaywall = true }
            } label: {
                Label(ent.isPro ? "以此冲新豆" : "以此冲新豆（Pro）",
                      systemImage: ent.isPro ? "plus" : "lock.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .glassProminentButtonStyle()
            .tint(DT.amber)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.sm)
        }
        .sheet(isPresented: $showNewBean) { BeanEditorView(prefill: recipe) }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.roundedNumber(18, weight: .bold)).foregroundStyle(DT.ink)
            Text(title).font(.caption2).foregroundStyle(DT.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.sm)
        .background(DT.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }
}
