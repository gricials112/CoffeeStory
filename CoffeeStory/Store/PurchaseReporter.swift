import Foundation

/// 购买成功上报：App 购买后通知 Worker，由 Worker 推送到 Bark
enum PurchaseReporter {

    /// Worker 地址（部署后的地址）
    private static let endpoint = URL(string: "https://asc-bark-notifier.keriadaring.workers.dev/report-purchase")!

    /// 上报购买成功
    /// - Parameters:
    ///   - productId: 购买的产品 ID
    ///   - transactionId: 交易 ID
    ///   - displayName: 产品显示名（可选）
    static func report(productId: String, transactionId: String, displayName: String? = nil) {
        Task {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: String] = [
                "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
                "productId": productId,
                "transactionId": transactionId,
                "displayName": displayName ?? productId,
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (_, resp) = try await URLSession.shared.data(for: request)
                if let httpResp = resp as? HTTPURLResponse {
                    print("[PurchaseReporter] reported: \(httpResp.statusCode)")
                }
            } catch {
                print("[PurchaseReporter] failed: \(error.localizedDescription)")
            }
        }
    }
}
