import StoreKit
import SwiftUI

@MainActor
class StoreKitModel: NSObject, ObservableObject {
    public var defaultPurchaseIdentifier: String
    public var purchaseIdentifiers: [String]

    private var productSet: Set<String> {
        var ans = [String]()
        ans.append(defaultPurchaseIdentifier)
        ans.append(contentsOf: purchaseIdentifiers)
        return Set(ans)
    }

    @Published public private(set) var products: [Product]?
    @Published public private(set) var defaultProduct: Product?

    @Published private(set) var purchasedIdentifiers = Set<String>()
    var updateListenerTask: Task<Void, Error>?

    init(defaultId: String, ids: [String]) {
        defaultPurchaseIdentifier = defaultId
        purchaseIdentifiers = ids

        super.init()

        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            // Initialize the store by starting a product request.
            try await retrieve()
        }

        SKPaymentQueue.default().add(self)
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }

    func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            // Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
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

    /// Update the products and update purchase identifiers
    func update() async throws {
        let products = try await Product.products(for: productSet)
        self.products = products
        for product in products {
            if let transaction = await product.latestTransaction {
                try await updatePurchasedIdentifiers(transaction.payloadValue)
            } else {
                objectWillChange.send()
                // can't get the latest transaction so assume it isn't purchased
                purchasedIdentifiers.remove(product.id)
            }
        }
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

    func retrieve(completion block: (([Product]) -> Void)? = nil) async throws {
        let products = try await Product.products(for: productSet)
        self.products = products
        for product in products {
            if product.id == defaultPurchaseIdentifier {
                defaultProduct = product
            }

            if let transaction = await product.latestTransaction {
                try await updatePurchasedIdentifiers(transaction.payloadValue)
            }
        }
        block?(products)
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
        objectWillChange.send()
        if transaction.revocationDate == nil {
            // check if the purchse is expired
            if let expirationDate = transaction.expirationDate {
                if expirationDate >= Date() {
                    purchasedIdentifiers.insert(transaction.productID)
                } else {
                    purchasedIdentifiers.remove(transaction.productID)
                }
            } else {
                // If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
                purchasedIdentifiers.insert(transaction.productID)
            }
        } else {
            // If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
            purchasedIdentifiers.remove(transaction.productID)
        }
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
