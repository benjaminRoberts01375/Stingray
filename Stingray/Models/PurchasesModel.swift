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
    public enum ProductIDs: String, CaseIterable {
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
        do { self.products = .ready(try await Product.products(for: [ProductIDs.supporter.rawValue])) }
        catch { self.products = .failed(error) }
        
        // Check to see if the user bought any previously
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == ProductIDs.supporter.rawValue {
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
        case failed(Error)
    }
    
    /// Purchase a product from StoreKit
    /// - Parameter product: Product to buy
    /// - Returns: The successfulness of the purchase
    /// - Throws: If there was an issue buying the product, either from buying or tampering
    public func purchase(_ product: Product) async throws(StoreErrors) -> PurchaseOutcome {
        let result: Product.PurchaseResult
        do { result = try await product.purchase() }
        catch { throw .purchaseFailed(product, error) }
        
        switch result {
        case .pending: return .waiting
        case .userCancelled: return .cancelled
        case .success(let tx):
            switch tx {
            case .unverified(_, let err): throw .tamperedPurchase(product, err)
            case .verified(let transaction):
                await transaction.finish()
                self.boughtSupporter = transaction.revocationDate == nil
                Log.info("User is now a supporter: \(self.boughtSupporter)")
                return .success
            }
        @unknown default: throw .purchasesUpdated
        }
    }
    
    /// Denotes the result of buying a product
    public enum PurchaseOutcome {
        /// The transaction is still loading
        case waiting
        /// The transaction worked correctly
        case success
        /// The user no longer wants to buy it
        case cancelled
    }
}
