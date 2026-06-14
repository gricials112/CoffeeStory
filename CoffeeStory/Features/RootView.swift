import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.colorScheme) private var colorSchemePref = "system"
    @State private var router = AppRouter()
    @State private var entitlements = Entitlements()
    @Environment(\.modelContext) private var modelContext

    private var scheme: ColorScheme? {
        switch colorSchemePref {
        case "light": .light
        case "dark":  .dark
        default:      nil
        }
    }

    private var onboardingShown: Binding<Bool> {
        Binding(get: { !hasOnboarded }, set: { if !$0 { hasOnboarded = true } })
    }

    var body: some View {
        TabView {
            Tab("豆架", systemImage: "bag.fill") {
                ShelfView()
                    .environment(router)
                    .environment(entitlements)
            }
            Tab("配方库", systemImage: "books.vertical.fill") {
                RecipesView()
                    .environment(router)
                    .environment(entitlements)
            }
            Tab("我的", systemImage: "person.crop.circle") {
                MeView()
                    .environment(router)
                    .environment(entitlements)
            }
        }
        .tint(DT.amber)
        .preferredColorScheme(scheme)
        .fullScreenCover(item: $router.presentedSession) { session in
            BrewFlowView(session: session)
                .environment(router)
                .environment(entitlements)
        }
        .fullScreenCover(isPresented: onboardingShown) {
            OnboardingView { hasOnboarded = true }
        }
        .sheet(isPresented: Bindable(router).showPaywall) {
            PaywallView()
                .environment(entitlements)
        }
        .task {
            #if DEBUG
            SampleData.seedIfRequested(modelContext)
            #endif
        }
    }
}
