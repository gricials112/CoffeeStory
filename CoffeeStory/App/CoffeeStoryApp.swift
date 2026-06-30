import SwiftUI
import SwiftData
import CloudKit
import UIKit

final class CoffeeStoryAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        NotificationCenter.default.post(name: .coffeeStoryCloudKitDidChange, object: nil)
        completionHandler(.newData)
    }
}

@main
struct CoffeeStoryApp: App {
    @UIApplicationDelegateAdaptor(CoffeeStoryAppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        guard let container = try? ModelContainer(
            for: Bean.self, Brew.self, ActiveBrewSession.self, RecipeArchive.self,
            configurations: config
        ) else {
            fatalError("无法初始化数据存储，请重启应用")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(DT.amber)
        }
        .modelContainer(modelContainer)
    }
}
