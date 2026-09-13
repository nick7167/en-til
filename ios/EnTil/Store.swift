import StoreKit
import Observation

@MainActor @Observable final class PackStore {
    var products: [Product] = []
    var message: String?
    var purchasing = false
    var purchasedPack: String?
    private var updates: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var pending: [UInt64: VerificationResult<Transaction>] = [:]
    private var client: GameClient?
    var prefix: String { Bundle.main.bundleIdentifier ?? "dev.adrez.entil.development" }
    private var isVisualFixture: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["ENTIL_SCREENSHOT_FIXTURE"] != nil
#else
        false
#endif
    }
    func priceLabel(_ pack: String) -> String? {
        // Presentation fixtures show target prices, never verified purchase access.
        if isVisualFixture {
            return (pack == "launch-bundle" ? 99 : 29).formatted(
                .currency(code: "DKK").locale(Locale(identifier: "da_DK")).precision(.fractionLength(0)))
        }
        return product(pack)?.displayPrice
    }
    func start(client: GameClient) async {
        guard updates == nil else { return }
        self.client = client
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.verify(result)
            }
        }
        await load()
        for await entitlement in Transaction.currentEntitlements { await verify(entitlement) }
        do { try await client.refreshOwnership() } catch { /* Previously verified access is retained by the server. */ }
    }
    func load() async {
        guard !isVisualFixture else { return }
        do { products = try await Product.products(for: Pack.all.filter { $0.id != "free" }.map { "\(prefix).\($0.id)" } + ["\(prefix).launch-bundle"]) }
        catch { message = "Priserne kunne ikke hentes. Prøv igen om lidt." }
    }
    func product(_ pack: String) -> Product? { products.first { $0.id == "\(prefix).\(pack)" } }
    func buy(_ pack: String) async {
        guard !isVisualFixture else { return }
        guard !purchasing, let product = product(pack) else { return }
        purchasing = true; message = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await verify(result)
            case .pending: message = "Købet afventer godkendelse. Du kan spille videre imens."
            case .userCancelled: break
            @unknown default: message = "Købet afventer bekræftelse."
            }
        } catch { message = "Købet kunne ikke gennemføres. Prøv igen." }
    }
    func restore() async {
        guard !isVisualFixture else { return }
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements { await verify(result) }
            try await client?.refreshOwnership()
            message = "Dine køb er gendannet."
        } catch { message = "Dine køb kunne ikke gendannes endnu. Prøv igen." }
    }
    private func verify(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, let client else {
            message = "Købet kunne ikke bekræftes af Apple."; return
        }
        do {
            try await client.verifyPurchase(result.jwsRepresentation)
            pending.removeValue(forKey: transaction.id)
            purchasedPack = String(transaction.productID.split(separator: ".").last ?? "")
            await transaction.finish()
        } catch let error as APIProblem where error.code == "purchase_revoked" {
            pending.removeValue(forKey: transaction.id)
            try? await client.refreshOwnership()
            await transaction.finish()
        } catch {
            pending[transaction.id] = result
            message = "Købet bliver kontrolleret. Vi prøver igen automatisk."
            scheduleRetry()
        }
    }
    private func scheduleRetry() {
        guard retry == nil else { return }
        retry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self else { return }
            self.retry = nil
            for result in Array(self.pending.values) { await self.verify(result) }
        }
    }
    func cheapestRoute(owned: Set<String>) -> String? {
        let missing = Pack.all.filter { $0.id != "free" && !owned.contains($0.id) }
        if isVisualFixture {
            guard !missing.isEmpty else { return nil }
            return 99 < missing.count * 29 ? "Samlepakken er billigst for de pakker, du mangler." : "De enkelte pakker er billigst for det, du mangler."
        }
        guard !missing.isEmpty, let bundle = product("launch-bundle"), missing.allSatisfy({ product($0.id) != nil }) else { return nil }
        let total = missing.reduce(Decimal.zero) { $0 + (product($1.id)?.price ?? 0) }
        return bundle.price < total ? "Samlepakken er billigst for de pakker, du mangler." : "De enkelte pakker er billigst for det, du mangler."
    }
}
