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
    
    private let exampleThemes: [ThemeModel] = [
        ThemeModel(darkTheme: .frosty, lightTheme: .frosty, colorScheme: .light),
        ThemeModel(darkTheme: .retro, lightTheme: .retro, colorScheme: .dark),
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
                .frame(maxWidth: .infinity)
                
                VStack {
                    if self.purchases.boughtSupporter {
                        VStack {
                            RainbowText(text: "Thanks!")
                                .font(.title3)
                                .bold()
                            Text("""
                        This really means a lot, and helps keep development and updates free for everyone else. Free and Open Source \
                        Software (FOSS) is some of the most important software made, and you just did your part to keep it possible.
                        """)
                            .multilineTextAlignment(.center)
                            .padding(.vertical)
                            Text("Thank you, and go watch something awesome in style :)")
                        }
                        .availableGlass()
                        Text("PS - Frosty with Space Vampires is my day-to-day setup.")
                            .foregroundStyle(.secondary)
                            .padding(.top)
                    }
                    else if let error = error { ErrorView(error: error, summary: "Failed to purchase") }
                    else {
                        switch self.purchases.products {
                        case .waiting, .fetching: ProgressView()
                        case .ready(let products):
                            if let product = (products.first { $0.id == PurchasesModel.ProductID.supporter.rawValue }) {
                                VStack {
                                    Text("Helping Out")
                                        .font(.title3)
                                        .bold()
                                    Text("""
                                    It takes a lot of time, work, and even some money to keep the development of Stingray going. \
                                    Funding is always appreciated but **never** required. No functionality is locked behind a \
                                    paywall, it's just a few animated themes and a big ol' thanks :)
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
                                .availableGlass()
                            }
                            else { ErrorView(error: StoreErrors.productUnavailable, summary: "Could not find product") }
                        case .failed(let error): ErrorView(error: error, summary: "Purchases not available")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(64)
        .onChange(of: self.purchases.boughtSupporter) { _, support in
            Log.critical("User has \(support ? "purchased" : "cancelled") the support tier")
        }
    }
}
