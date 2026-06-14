import SwiftUI
import StoreKit

// MARK: - 免费额度
enum FreeLimits {
    static let maxActiveBeans = 2
    static let maxBrewsPerBean = 6
}

// MARK: - Pro 权益
@MainActor
@Observable
final class Entitlements {
    static let productID = "com.coffestory.dialin.pro"

    var isPro = false
    var product: Product?
    var purchasing = false
    var loadFailed = false

    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update {
                    await t.finish()
                    await self?.refresh()
                }
            }
        }
        Task { await loadProduct(); await refresh() }
    }

    deinit { updatesTask?.cancel() }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            loadFailed = (product == nil)
        } catch {
            loadFailed = true
        }
    }

    func refresh() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.productID,
               t.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    isPro = true
                    Haptics.success()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    var priceText: String { product?.displayPrice ?? "¥28" }
}
