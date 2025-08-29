//
//  SharedImportView.swift
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

struct SharedImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var sharedFileManager: SharedFileManager
    @EnvironmentObject private var dataStore: DataStore
    
    @State private var currentFileIndex = 0
    @State private var title = ""
    @State private var artist = ""
    @State private var key = ""
    @State private var tags = ""
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0
    @State private var notes = ""
    @State private var isImporting = false
    @State private var importError: Error?
    
    private var currentFile: SharedFileManager.SharedFile? {
        guard currentFileIndex < sharedFileManager.importedFiles.count else { return nil }
        return sharedFileManager.importedFiles[currentFileIndex]
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let file = currentFile {
                    Form {
                        Section("Imported File") {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(file.name)
                                        .font(.headline)
                                    Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Section("Song Information") {
                            TextField("Title", text: $title)
                                .textInputAutocapitalization(.words)
                            
                            TextField("Artist", text: $artist)
                                .textInputAutocapitalization(.words)
                            
                            TextField("Key (e.g., C, Am, G#)", text: $key)
                                .textInputAutocapitalization(.characters)
                        }
                        
                        Section("Additional Details") {
                            TextField("Tags (comma-separated)", text: $tags)
                                .textInputAutocapitalization(.none)
                            
                            HStack {
                                Text("Duration")
                                Spacer()
                                Picker("Minutes", selection: $durationMinutes) {
                                    ForEach(0..<60) { minute in
                                        Text("\(minute)")
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                
                                Text(":")
                                
                                Picker("Seconds", selection: $durationSeconds) {
                                    ForEach(0..<60) { second in
                                        Text(String(format: "%02d", second))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                        
                        if sharedFileManager.importedFiles.count > 1 {
                            Section("Progress") {
                                HStack {
                                    Text("File \(currentFileIndex + 1) of \(sharedFileManager.importedFiles.count)")
                                    Spacer()
                                    if currentFileIndex < sharedFileManager.importedFiles.count - 1 {
                                        Button("Skip") {
                                            skipCurrentFile()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        setupFileInfo()
                    }
                } else {
                    ContentUnavailableView(
                        "No Files to Import",
                        systemImage: "tray",
                        description: Text("All shared files have been processed.")
                    )
                }
            }
            .navigationTitle("Import Shared PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        sharedFileManager.cleanupAllSharedFiles()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importCurrentFile()
                    }
                    .disabled(title.isEmpty || isImporting || currentFile == nil)
                }
            }
            .overlay {
                if isImporting {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Importing...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                }
            }
        }
    }
    
    private func setupFileInfo() {
        guard let file = currentFile else { return }
        
        let fileName = file.url.deletingPathExtension().lastPathComponent
        if title.isEmpty {
            title = fileName.replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "imported pdf ", with: "")
                .trimmingCharacters(in: .whitespaces)
                .capitalized
        }
    }
    
    private func importCurrentFile() {
        guard let file = currentFile else { return }
        
        isImporting = true
        
        Task {
            do {
                let tagsArray = tags.isEmpty ? nil : tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                let totalSeconds = (durationMinutes * 60) + durationSeconds
                let durationSecs = totalSeconds > 0 ? Int32(totalSeconds) : nil
                
                _ = try await sharedFileManager.importSharedFile(
                    file,
                    with: title,
                    artist: artist.isEmpty ? nil : artist,
                    key: key.isEmpty ? nil : key,
                    tags: tagsArray,
                    notes: notes.isEmpty ? nil : notes,
                    durationSecs: durationSecs,
                    context: viewContext
                )
                
                await MainActor.run {
                    dataStore.loadSongs()
                    proceedToNext()
                }
            } catch {
                await MainActor.run {
                    importError = error
                    isImporting = false
                }
            }
        }
    }
    
    private func skipCurrentFile() {
        guard let file = currentFile else { return }
        sharedFileManager.cleanupSharedFile(file)
        proceedToNext()
    }
    
    private func proceedToNext() {
        isImporting = false
        
        if currentFileIndex < sharedFileManager.importedFiles.count - 1 {
            currentFileIndex += 1
            resetForm()
            setupFileInfo()
        } else {
            dismiss()
        }
    }
    
    private func resetForm() {
        title = ""
        artist = ""
        key = ""
        tags = ""
        durationMinutes = 0
        durationSeconds = 0
        notes = ""
    }
}