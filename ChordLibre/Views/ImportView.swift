//
//  ImportView.swift
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
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var dataStore: DataStore
    
    @State private var selectedURLs: [URL] = []
    @State private var pdfDataList: [(url: URL, data: Data)] = []
    @State private var showingFilePicker = false
    @State private var showingCamera = false
    @State private var importedSongs: [Song] = []
    
    @State private var songMetadata: [URL: SongMetadata] = [:]
    @State private var currentEditingURL: IdentifiableURL?
    
    @State private var isImporting = false
    @State private var importError: Error?
    @State private var showingDuplicateAlert = false
    @State private var duplicateSong: Song?
    @State private var importProgress: (current: Int, total: Int) = (0, 0)
    
    struct SongMetadata {
        var title: String = ""
        var artist: String = ""
        var key: String = ""
        var tags: String = ""
        var durationMinutes: Int = 0
        var durationSeconds: Int = 0
        var notes: String = ""
    }
    
    private func parseFilename(_ filename: String) -> SongMetadata {
        var metadata = SongMetadata()
        
        // Look for patterns like "Title - Artist" or "Title-Artist"
        if let separatorRange = filename.range(of: " - ") {
            // Found " - " separator
            let title = String(filename[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let artist = String(filename[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            metadata.title = title.isEmpty ? filename : title
            metadata.artist = artist.isEmpty ? "" : artist
        } else if let separatorRange = filename.range(of: "-") {
            // Found "-" separator (no spaces)
            let title = String(filename[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let artist = String(filename[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Only split if both parts have reasonable length (avoid splitting things like "A-major")
            if title.count >= 2 && artist.count >= 2 {
                metadata.title = title
                metadata.artist = artist
            } else {
                metadata.title = filename
            }
        } else {
            // No separator found, use entire filename as title
            metadata.title = filename
        }
        
        return metadata
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Import Source") {
                    HStack(spacing: 20) {
                        Button {
                            showingFilePicker = true
                        } label: {
                            VStack {
                                Image(systemName: "doc.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.accentColor)
                                Text("Files")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical)
                    
                }
                
                if !pdfDataList.isEmpty {
                    Section("Selected PDFs (\(pdfDataList.count))") {
                        ForEach(pdfDataList, id: \.url) { item in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(songMetadata[item.url]?.title ?? item.url.deletingPathExtension().lastPathComponent)
                                        .font(.body)
                                    if let artist = songMetadata[item.url]?.artist, !artist.isEmpty {
                                        Text(artist)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    currentEditingURL = IdentifiableURL(url: item.url)
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let url = pdfDataList[index].url
                                pdfDataList.remove(at: index)
                                songMetadata.removeValue(forKey: url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(pdfDataList.count == 1 ? "" : "(\(pdfDataList.count))")") {
                        performImport()
                    }
                    .disabled(pdfDataList.isEmpty || isImporting)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingCamera) {
                DocumentScannerView { scannedData in
                    // Handle camera scan
                    showingCamera = false
                }
            }
            .sheet(item: $currentEditingURL) { identifiableURL in
                MetadataEditView(
                    url: identifiableURL.url,
                    metadata: Binding(
                        get: { songMetadata[identifiableURL.url] ?? SongMetadata(title: identifiableURL.url.deletingPathExtension().lastPathComponent) },
                        set: { songMetadata[identifiableURL.url] = $0 }
                    )
                )
            }
            .alert("Duplicate PDF", isPresented: $showingDuplicateAlert) {
                Button("Use Existing") {
                    dismiss()
                }
                Button("Import as New") {
                    forceImport()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This PDF has already been imported. Would you like to use the existing song or import it as a new copy?")
            }
            .overlay {
                if isImporting {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .overlay {
                            VStack {
                                ProgressView()
                                Text("Importing \(importProgress.current + 1) of \(importProgress.total)...")
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedURLs = urls
            
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    do {
                        let data = try Data(contentsOf: url)
                        pdfDataList.append((url: url, data: data))
                        
                        // Parse filename for title and artist
                        let filename = url.deletingPathExtension().lastPathComponent
                        let parsedMetadata = parseFilename(filename)
                        songMetadata[url] = parsedMetadata
                    } catch {
                        importError = error
                    }
                }
            }
            
        case .failure(let error):
            importError = error
        }
    }
    
    private func performImport() {
        guard !pdfDataList.isEmpty else { return }
        
        isImporting = true
        importProgress = (0, pdfDataList.count)
        
        Task {
            var successCount = 0
            var failedImports: [(url: URL, error: Error)] = []
            
            for (index, item) in pdfDataList.enumerated() {
                await MainActor.run {
                    importProgress = (index, pdfDataList.count)
                }
                
                do {
                    let song = try await PDFImportService.shared.importPDF(
                        data: item.data,
                        context: viewContext
                    )
                    
                    let metadata = songMetadata[item.url] ?? SongMetadata()
                    song.title = metadata.title.isEmpty ? item.url.deletingPathExtension().lastPathComponent : metadata.title
                    song.artist = metadata.artist.isEmpty ? nil : metadata.artist
                    song.key = metadata.key.isEmpty ? nil : metadata.key
                    song.notes = metadata.notes.isEmpty ? nil : metadata.notes
                    
                    if !metadata.tags.isEmpty {
                        let tagsArray = metadata.tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                        song.tags = tagsArray as NSObject
                    }
                    
                    let totalSeconds = (metadata.durationMinutes * 60) + metadata.durationSeconds
                    if totalSeconds > 0 {
                        song.durationSecs = Int32(totalSeconds)
                    }
                    
                    importedSongs.append(song)
                    successCount += 1
                } catch PDFImportService.ImportError.duplicateFound {
                    // Skip duplicates silently for batch import
                    continue
                } catch {
                    failedImports.append((url: item.url, error: error))
                }
            }
            
            // Save all imported songs
            if !importedSongs.isEmpty {
                do {
                    try viewContext.save()
                    await MainActor.run {
                        dataStore.loadSongs()
                    }
                } catch {
                    await MainActor.run {
                        importError = error
                    }
                }
            }
            
            await MainActor.run {
                isImporting = false
                if failedImports.isEmpty {
                    dismiss()
                } else {
                    // Show error summary
                    importError = ImportError.batchImportPartialFailure(
                        succeeded: successCount,
                        failed: failedImports.count
                    )
                }
            }
        }
    }
    
    private func forceImport() {
        
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let completion: (Data?) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

enum ImportError: LocalizedError {
    case batchImportPartialFailure(succeeded: Int, failed: Int)
    
    var errorDescription: String? {
        switch self {
        case .batchImportPartialFailure(let succeeded, let failed):
            return "Imported \(succeeded) songs successfully. \(failed) failed to import."
        }
    }
}

// Use a wrapper struct to avoid extending URL directly
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct MetadataEditView: View {
    let url: URL
    @Binding var metadata: ImportView.SongMetadata
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Song Information") {
                    TextField("Title", text: $metadata.title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Artist", text: $metadata.artist)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Key (e.g., C, Am, G#)", text: $metadata.key)
                        .textInputAutocapitalization(.characters)
                }
                
                Section("Additional Details") {
                    TextField("Tags (comma-separated)", text: $metadata.tags)
                        .textInputAutocapitalization(.none)
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("Minutes", selection: $metadata.durationMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 60)
                        
                        Text(":")
                        
                        Picker("Seconds", selection: $metadata.durationSeconds) {
                            ForEach(0..<60) { second in
                                Text(String(format: "%02d", second))
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 60)
                    }
                    
                    TextField("Notes", text: $metadata.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Metadata")
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
