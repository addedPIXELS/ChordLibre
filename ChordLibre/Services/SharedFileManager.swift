//
//  SharedFileManager.swift
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
import CoreData
import SwiftUI

@MainActor
class SharedFileManager: ObservableObject {
    @Published var hasNewImports = false
    @Published var importedFiles: [SharedFile] = []
    
    private let sharedContainerURL: URL?
    
    struct SharedFile: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let data: Data
    }
    
    init() {
        self.sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.chordlibre.app")
    }
    
    func checkForSharedFiles() {
        guard let sharedContainer = sharedContainerURL else {
            print("Unable to access shared container")
            return
        }
        
        let incomingFolder = sharedContainer.appendingPathComponent("Incoming")
        
        guard FileManager.default.fileExists(atPath: incomingFolder.path) else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: incomingFolder, includingPropertiesForKeys: nil)
            let pdfFiles = files.filter { $0.pathExtension.lowercased() == "pdf" }
            
            if !pdfFiles.isEmpty {
                var newFiles: [SharedFile] = []
                
                for fileURL in pdfFiles {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let sharedFile = SharedFile(
                            url: fileURL,
                            name: fileURL.lastPathComponent,
                            data: data
                        )
                        newFiles.append(sharedFile)
                    } catch {
                        print("Error reading shared file: \(error)")
                    }
                }
                
                self.importedFiles = newFiles
                self.hasNewImports = !newFiles.isEmpty
            }
        } catch {
            print("Error accessing shared files: \(error)")
        }
    }
    
    func importSharedFile(_ sharedFile: SharedFile, with title: String, artist: String?, key: String?, tags: [String]?, notes: String?, durationSecs: Int32?, context: NSManagedObjectContext) async throws -> Song {
        
        let song = try await PDFImportService.shared.importPDF(data: sharedFile.data, context: context)
        
        song.title = title
        song.artist = artist
        song.key = key
        song.notes = notes
        
        if let tags = tags, !tags.isEmpty {
            song.tags = tags as NSObject
        }
        
        if let duration = durationSecs, duration > 0 {
            song.durationSecs = duration
        }
        
        try context.save()
        
        cleanupSharedFile(sharedFile)
        
        return song
    }
    
    func cleanupSharedFile(_ sharedFile: SharedFile) {
        do {
            try FileManager.default.removeItem(at: sharedFile.url)
            importedFiles.removeAll { $0.id == sharedFile.id }
            
            if importedFiles.isEmpty {
                hasNewImports = false
            }
        } catch {
            print("Error removing shared file: \(error)")
        }
    }
    
    func cleanupAllSharedFiles() {
        for file in importedFiles {
            cleanupSharedFile(file)
        }
    }
}