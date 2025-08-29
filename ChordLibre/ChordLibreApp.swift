//
//  ChordLibreApp.swift
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

@main
struct ChordLibreApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var sharedFileManager = SharedFileManager()
    @StateObject private var iapManager = IAPManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(sharedFileManager)
                .onOpenURL { url in
                    handleURL(url)
                }
                .onAppear {
                    sharedFileManager.checkForSharedFiles()
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        if url.scheme == "chordlibre" && url.host == "import" {
            sharedFileManager.checkForSharedFiles()
        }
    }
}
