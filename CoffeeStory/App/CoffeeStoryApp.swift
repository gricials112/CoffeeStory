import SwiftUI
import SwiftData

@main
struct CoffeeStoryApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(DT.amber)
        }
        .modelContainer(for: [Bean.self, Brew.self, ActiveBrewSession.self, RecipeArchive.self])
    }
}
