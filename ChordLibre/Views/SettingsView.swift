//
//  SettingsView.swift
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

import SwiftUI

struct SettingsView: View {
    @AppStorage("autoScrollSpeed") private var autoScrollSpeed = 1.0
    @AppStorage("defaultFitMode") private var defaultFitMode = "width"
    @AppStorage("keepScreenAwake") private var keepScreenAwake = true
    @AppStorage("showPageNumbers") private var showPageNumbers = true
    @AppStorage("swipeNavigation") private var swipeNavigation = true
    @AppStorage("tapZones") private var tapZones = true
    @AppStorage("useHighContrast") private var useHighContrast = false
    @StateObject private var adManager = AdManager.shared
    @State private var showingRemoveAds = false
    
    var body: some View {
        Form {
            // Support section - only show if not already supported
            if !adManager.adsRemoved {
                Section {
                    Button {
                        showingRemoveAds = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Support Development")
                                    .foregroundColor(.primary)
                                Text("One-time tip - £0.99")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Section("Performance Settings") {
                Toggle("Keep Screen Awake", isOn: $keepScreenAwake)
                Toggle("Show Page Numbers", isOn: $showPageNumbers)
                
                VStack(alignment: .leading) {
                    Text("Auto-Scroll Speed")
                    Slider(value: $autoScrollSpeed, in: 0.5...3.0, step: 0.5)
                    Text("\(autoScrollSpeed, specifier: "%.1f")x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Picker("Default Fit Mode", selection: $defaultFitMode) {
                    Text("Fit Width").tag("width")
                    Text("Fit Page").tag("page")
                }
            }
            
            Section("Navigation") {
                Toggle("Swipe Navigation", isOn: $swipeNavigation)
                Toggle("Tap Zones", isOn: $tapZones)
            }
            
            Section("Accessibility") {
                Toggle("High Contrast", isOn: $useHighContrast)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingRemoveAds) {
            RemoveAdsView()
        }
    }
}

struct PerformingStatusView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Currently Performing")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Return to the performance or end it to continue browsing")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Now Performing")
    }
}