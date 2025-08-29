//
//  AdManager.swift
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
import SwiftUI

@MainActor
class AdManager: ObservableObject {
    static let shared = AdManager()
    
    @Published var adsRemoved: Bool {
        didSet {
            UserDefaults.standard.set(adsRemoved, forKey: "ads_removed")
        }
    }
    
    private init() {
        self.adsRemoved = UserDefaults.standard.bool(forKey: "ads_removed")
    }
    
    func removeAds() {
        adsRemoved = true
    }
}

// Native promotional banner without third-party ads
struct PromotionalBanner: View {
    @StateObject private var adManager = AdManager.shared
    @State private var showingRemoveAds = false
    @State private var currentTipIndex = 0
    
    let tips = [
        ("lightbulb.fill", "Tip: Swipe between pages in performance mode"),
        ("heart.fill", "Enjoying ChordLibre? Support indie development"),
        ("music.note", "Tap songs to view, hold for quick actions"),
        ("rectangle.stack.fill", "Organize songs into setlists for gigs")
    ]
    
    var body: some View {
        if !adManager.adsRemoved {
            VStack(spacing: 0) {
                Divider()
                
                Button {
                    showingRemoveAds = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tips[currentTipIndex].0)
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                        
                        Text(tips[currentTipIndex].1)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("Support")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onAppear {
                startTipRotation()
            }
            .sheet(isPresented: $showingRemoveAds) {
                RemoveAdsView()
            }
        }
    }
    
    private func startTipRotation() {
        Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentTipIndex = (currentTipIndex + 1) % tips.count
            }
        }
    }
}

// Simplified ad container
struct AdBannerContainer: View {
    var body: some View {
        PromotionalBanner()
    }
}