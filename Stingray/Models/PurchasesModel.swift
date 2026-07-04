//
//  PurchasesModel.swift
//  Stingray
//
//  Created by Ben Roberts on 4/4/26.
//

import StoreKit

/// Tracks any purchases made in Stingray
@Observable
public final class PurchasesModel {
    /// Products from AppStore Connect
    public private(set) var products: ProductDownloadStatus

    /// Actually bought the supporter tier
    public var boughtSupporter: Bool

    /// A simple string that contains the ID for the supporter tier
    public enum ProductID: String, CaseIterable {
        case supporter = "com.benlab.Stingray.Supporter"
    }

    /// Setup purchases with AppStore Connect
    public init() {
        self.products = .waiting
        self.boughtSupporter = false
    }

    /// This needs to be called to get the available products and restore purchases
    public func setupProducts() async {
        // Get all available products
        self.products = .fetching
        do { self.products = .ready(try await Product.products(for: [ProductID.supporter.rawValue])) }
        catch { self.products = .failed(StoreErrors.productsUnavailable(error)) }

        // Check to see if the user bought any previously
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == ProductID.supporter.rawValue {
                    self.boughtSupporter = transaction.revocationDate == nil // False = revoked
                    Log.info("User is a supporter: \(self.boughtSupporter)")
                }
            default: continue
            }
        }
    }

    /// Tracks if the products were able to be synced
    public enum ProductDownloadStatus {
        /// Products have yet to be fetched
        case waiting
        /// Products are in the midst of being fetched
        case fetching
        /// Products have been fetched and are ready to go
        case ready([Product])
        /// Products failed to fetch
        case failed(RError)
    }

    /// Purchase a product from StoreKit
    /// - Parameter product: Product to buy
    /// - Throws: If there was an issue buying the product, either from buying or tampering
    /// - Important: This function does not return any state other than failures, and instead relies
    /// on observing the relevant `bought` variable
    public func purchase(_ product: Product) async throws(StoreErrors) {
        let result: Product.PurchaseResult
        do { result = try await product.purchase() }
        catch { throw .purchaseFailed(product, error) }

        switch result {
        case .pending: return
        case .userCancelled: return
        case .success(let tx):
            switch tx {
            case .unverified(_, let err): throw .tamperedPurchase(product, err)
            case .verified(let transaction):
                await transaction.finish()
                self.boughtSupporter = transaction.revocationDate == nil
                Log.info("User is now a supporter: \(self.boughtSupporter)")
            }
        @unknown default: throw .purchasesUpdated
        }
    }
}
