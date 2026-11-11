import Combine
import StoreKit
import SwiftUI

@MainActor
class StoreKitModel: NSObject, ObservableObject {
    public let defaultPurchaseIdentifier: String
    public let purchaseIdentifiers: [String]

    private lazy var productSet: Set<String> = {
        var ans = [String]()
        ans.append(defaultPurchaseIdentifier)
        ans.append(contentsOf: purchaseIdentifiers)
        return Set(ans)
    }()

    @Published public private(set) var products: [Product]?
    @Published public private(set) var defaultProduct: Product?
    /// Initial verified entitlements have been checked, independently of product availability.
    @Published public private(set) var hasInitialized = false

    @Published private(set) var purchasedIdentifiers = Set<String>()
    private var entitlementExpirations = [String: Date]()
    private var nonExpiringEntitlements = Set<String>()
    var updateListenerTask: Task<Void, Error>?
    private var initializationTask: Task<Void, Error>?
    private var productTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var recoverySubscriptions = Set<AnyCancellable>()
    private let loadProducts: (Set<String>) async throws -> [Product]

    init(
        defaultId: String,
        ids: [String],
        connectivity: ConnectivityRecovery = .shared,
        loadProducts: @escaping (Set<String>) async throws -> [Product] = {
            try await Product.products(for: $0)
        }
    ) {
        defaultPurchaseIdentifier = defaultId
        purchaseIdentifiers = ids
        self.loadProducts = loadProducts

        super.init()

        #if DEBUG
        // UI tests exercise Pro-only Lobsters interactions on a clean
        // Simulator without depending on StoreKit test transactions.
        if ProcessInfo.processInfo.arguments.contains("--claw-ui-testing") {
            purchasedIdentifiers.insert(defaultPurchaseIdentifier)
            hasInitialized = true
        }
        #endif

        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task { [weak self] in
            // Start initialization eagerly while sharing the same request with
            // any view that also needs to await the initial entitlement state.
            try? await self?.initialize()
        }

        connectivity.reconnections
            .sink { [weak self] in self?.scheduleRecovery() }
            .store(in: &recoverySubscriptions)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRecovery() }
            .store(in: &recoverySubscriptions)

        SKPaymentQueue.default().add(self)
    }

    deinit {
        updateListenerTask?.cancel()
        productTask?.cancel()
        recoveryTask?.cancel()
        SKPaymentQueue.default().remove(self)
    }

    func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            // Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                try Task.checkCancellation()
                do {
                    let transaction = try await self.checkVerified(result)

                    // Deliver content to the user.
                    await self.updatePurchasedIdentifiers(transaction)

                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    // StoreKit has a receipt it can read but it failed verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }

    /// App Store sync and update products
    func restore(completion block: (() -> Void)? = nil) async throws {
        try await AppStore.sync()

        try await update()

        block?()
    }

    /// Loads verified entitlements once, sharing initialization between callers.
    func initialize() async throws {
        guard !hasInitialized else {
            return
        }
        if let initializationTask {
            try await initializationTask.value
            return
        }

        let task = Task<Void, Error> { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.refreshEntitlements()
            self.hasInitialized = true
            // Catalog loading can fail or stall on a plane. It must never
            // prevent access to purchases StoreKit has already verified.
            self.productTask = Task { [weak self] in
                try? await self?.retrieve()
            }
        }
        initializationTask = task
        defer { initializationTask = nil }
        try await task.value
    }

    /// Update the products and update purchase identifiers
    func update() async throws {
        await refreshEntitlements()
        hasInitialized = true
        try await retrieve()
    }

    private func scheduleRecovery() {
        guard recoveryTask == nil else { return }
        recoveryTask = Task { [weak self] in
            guard let self else { return }
            defer { self.recoveryTask = nil }
            // Reading current entitlements uses StoreKit's verified transactions.
            // AppStore.sync is reserved for the user's explicit Restore action.
            if !self.hasInitialized {
                try? await self.initialize()
            } else {
                #if DEBUG
                if !ProcessInfo.processInfo.arguments.contains("--claw-ui-testing") {
                    await self.refreshEntitlements()
                }
                #else
                await self.refreshEntitlements()
                #endif
            }
            // Retry prices separately so a slow App Store request cannot block
            // login recovery or replace the verified purchase state.
            self.productTask?.cancel()
            self.productTask = Task { [weak self] in
                try? await self?.retrieve()
            }
        }
    }

    private func refreshEntitlements() async {
        var identifiers = Set<String>()
        var expirations = [String: Date]()
        var nonExpiring = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  productSet.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                continue
            }
            identifiers.insert(transaction.productID)
            if let expiration = transaction.expirationDate {
                expirations[transaction.productID] = expiration
            } else {
                nonExpiring.insert(transaction.productID)
            }
        }
        entitlementExpirations = expirations
        nonExpiringEntitlements = nonExpiring
        purchasedIdentifiers = identifiers
        persistLobstersEntitlement()
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        // Begin a purchase.
        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification)

            // Deliver content to the user.
            await updatePurchasedIdentifiers(transaction)

            // Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled:
            throw SKError(.paymentCancelled)
        case .pending:
            return nil
        @unknown default:
            throw SKError(.unknown)
        }
    }

    private func retrieve() async throws {
        let products = try await loadProducts(productSet)
        try Task.checkCancellation()
        self.products = products
        defaultProduct = products.first { $0.id == defaultPurchaseIdentifier }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check if the transaction passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit has parsed the JWS but failed verification. Don't deliver content to the user.
            throw SKError(.clientInvalid)
        case let .verified(safe):
            // If the transaction is verified, unwrap and return it.
            return safe
        }
    }

    func updatePurchasedIdentifiers(_ transaction: StoreKit.Transaction) async {
        guard productSet.contains(transaction.productID) else { return }
        objectWillChange.send()
        if transaction.revocationDate == nil, !transaction.isUpgraded {
            // check if the purchse is expired
            if let expirationDate = transaction.expirationDate {
                if expirationDate >= Date() {
                    purchasedIdentifiers.insert(transaction.productID)
                    entitlementExpirations[transaction.productID] = expirationDate
                    nonExpiringEntitlements.remove(transaction.productID)
                } else {
                    purchasedIdentifiers.remove(transaction.productID)
                    entitlementExpirations.removeValue(forKey: transaction.productID)
                    nonExpiringEntitlements.remove(transaction.productID)
                }
            } else {
                // If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
                purchasedIdentifiers.insert(transaction.productID)
                entitlementExpirations.removeValue(forKey: transaction.productID)
                nonExpiringEntitlements.insert(transaction.productID)
            }
        } else {
            // If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
            purchasedIdentifiers.remove(transaction.productID)
            entitlementExpirations.removeValue(forKey: transaction.productID)
            nonExpiringEntitlements.remove(transaction.productID)
        }
        persistLobstersEntitlement()
    }

    private func persistLobstersEntitlement() {
        guard !purchasedIdentifiers.isEmpty else {
            LobstersEntitlementStore.update(
                isEntitled: false,
                validUntil: nil
            )
            return
        }

        let hasNonExpiringEntitlement = !purchasedIdentifiers.isDisjoint(
            with: nonExpiringEntitlements
        )
        let validUntil = hasNonExpiringEntitlement
            ? nil
            : purchasedIdentifiers.compactMap {
                entitlementExpirations[$0]
            }.max()
        LobstersEntitlementStore.update(
            isEntitled: true,
            validUntil: validUntil
        )
    }

    var owned: Bool {
        !purchasedIdentifiers.isEmpty
    }
}

extension StoreKitModel {
    static var pro = StoreKitModel(defaultId: "claw.cosmetics.yearly.renew", ids: ["claw.cosmetics.monthly.renew", "claw.cosmetics.yearly.renew"])
}

extension StoreKitModel: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // no-op
    }

    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return true
    }
}
