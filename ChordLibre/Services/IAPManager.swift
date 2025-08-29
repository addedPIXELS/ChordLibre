//
//  IAPManager.swift
//  ChordLibre
//
//  Created by Yannick McCabe-Costa (yannick@addedpixels.com) on 29/08/2025.
//  Copyright © 2025 addedPIXELS Limited. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class IAPManager: ObservableObject {
    static let shared = IAPManager()
    
    @Published var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var purchaseError: String?
    
    private let removeAdsProductID = "com.addedpixels.chordlibre.supporttip"
    private var updateTask: Task<Void, Never>?
    private var transactionListener: Task<Void, Never>?
    
    init() {
        updateTask = Task { @MainActor in
            await requestProducts()
            await updatePurchasedProducts()
        }
        
        // Listen for transaction updates
        transactionListener = Task { @MainActor in
            await listenForTransactions()
        }
    }
    
    deinit {
        updateTask?.cancel()
        transactionListener?.cancel()
    }
    
    @MainActor
    func requestProducts() async {
        do {
            let productIdentifiers = [removeAdsProductID]
            let fetchedProducts = try await Product.products(for: productIdentifiers)
            products = fetchedProducts
        } catch {
            print("Failed to load products: \(error)")
            purchaseError = "Failed to load products"
        }
    }
    
    func purchaseRemoveAds() async {
        await MainActor.run {
            guard products.first(where: { $0.id == removeAdsProductID }) != nil else {
                purchaseError = "Product not found"
                return
            }
            
            guard AppStore.canMakePayments else {
                purchaseError = "Purchases are not allowed"
                return
            }
            
            purchaseInProgress = true
            purchaseError = nil
        }
        
        do {
            guard let product = await MainActor.run(body: { products.first(where: { $0.id == removeAdsProductID }) }) else { return }
            let result = try await product.purchase()
            
            await MainActor.run {
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        // Handle successful purchase
                        AdManager.shared.removeAds()
                        purchaseInProgress = false
                        Task {
                            await transaction.finish()
                        }
                        
                    case .unverified(_, let error):
                        purchaseError = "Purchase verification failed: \(error)"
                        purchaseInProgress = false
                    }
                    
                case .pending:
                    // Purchase is pending (e.g., waiting for parental approval)
                    purchaseInProgress = false
                    
                case .userCancelled:
                    // User cancelled the purchase
                    purchaseInProgress = false
                    
                @unknown default:
                    purchaseInProgress = false
                }
            }
        } catch {
            await MainActor.run {
                purchaseError = error.localizedDescription
                purchaseInProgress = false
            }
        }
    }
    
    @MainActor
    func restorePurchases() async {
        purchaseInProgress = true
        purchaseError = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            purchaseInProgress = false
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
            purchaseInProgress = false
        }
    }
    
    @MainActor
    private func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == removeAdsProductID {
                    AdManager.shared.removeAds()
                }
            case .unverified(_, _):
                break
            }
        }
    }
    
    @MainActor
    private func listenForTransactions() async {
        // Listen for transaction updates that happen outside the app
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                // Handle the transaction
                if transaction.productID == removeAdsProductID {
                    AdManager.shared.removeAds()
                    await transaction.finish()
                }
                
            case .unverified(let transaction, let error):
                // Transaction failed verification
                print("Transaction verification failed: \(error)")
                // Still finish the transaction to avoid it being stuck
                await transaction.finish()
            }
        }
    }
}

struct RemoveAdsView: View {
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var adManager = AdManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Support Development")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Help support indie development and remove the tips banner")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Remove the tips banner")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Support an indie developer")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("One-time purchase, yours forever")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Help fund new features")
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if let product = iapManager.products.first {
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await iapManager.purchaseRemoveAds()
                            }
                        } label: {
                            HStack {
                                if iapManager.purchaseInProgress {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Support - \(product.displayPrice)")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(iapManager.purchaseInProgress || adManager.adsRemoved)
                        
                        Button {
                            Task {
                                await iapManager.restorePurchases()
                            }
                        } label: {
                            Text("Restore Purchase")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(iapManager.purchaseInProgress)
                    }
                } else {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                if let error = iapManager.purchaseError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if adManager.adsRemoved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Thank you for your support!")
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}