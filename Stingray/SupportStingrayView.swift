//
//  SupportStingray.swift
//  Stingray
//
//  Created by Ben Roberts on 4/12/26.
//

import StoreKit
import SwiftUI

public struct SupportStingrayView: View {
    @Environment(PurchasesModel.self) private var purchases: PurchasesModel
    @State private var error: RError?
    
    private let exampleThemes: [ThemeModel] = [ // TODO: Temp themes. Real supporte themes will need to be used here
        ThemeModel(darkTheme: .frosty, lightTheme: .frosty, colorScheme: .light),
        ThemeModel(darkTheme: .void, lightTheme: .void, colorScheme: .dark),
        ThemeModel(darkTheme: .spaceVampires, lightTheme: .spaceVampires, colorScheme: .dark)
    ]
    
    public var body: some View {
        VStack {
            Text("Supporting Stingray")
                .font(.title)
                .bold()
            Spacer()
            HStack {
                VStack {
                    ForEach(self.exampleThemes) { theme in
                        ThemeExampleView()
                            .padding(.vertical)
                            .stingrayBackground()
                            .colorScheme(theme.currentTheme.colorScheme)
                            .environment(theme)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                VStack {
                    if self.purchases.boughtSupporter {
                        Text("Thanks!")
                            .font(.title)
                            .bold()
                    }
                    else if let error = error { ErrorView(error: error, summary: "Failed to purchase") }
                    else {
                        switch self.purchases.products {
                        case .waiting, .fetching: ProgressView()
                        case .ready(let products):
                            if let product = (products.first { $0.id == PurchasesModel.ProductID.supporter.rawValue }) {
                                Text("Helping Out")
                                    .font(.title3)
                                    .bold()
                                Text("""
                                    It takes a lot of time, work, and even some money to keep the development of Stingray going. \
                                    Funding is always appreciated but **never** required. It helps keep Stingray going, and you \
                                    get some fun themes :)
                                    """)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical)
                                Button {
                                    Task {
                                        do { try await self.purchases.purchase(product) }
                                        catch let error as RError { self.error = error }
                                    }
                                }
                                label: { Text("Support for \(product.displayPrice)") }
                            }
                            else { ErrorView(error: StoreErrors.productUnavailable, summary: "Could not find product") }
                        case .failed(let error): ErrorView(error: error, summary: "Purchases not available")
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 64)
        .onChange(of: self.purchases.boughtSupporter) { _, support in
            Log.critical("User has \(support ? "purchased" : "cancelled") the support tier")
        }
    }
}
