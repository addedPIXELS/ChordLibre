//
//  SongDetailView.swift
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

struct SongDetailView: View {
    let song: Song
    let onPerform: () -> Void
    let onEdit: (() -> Void)?
    let onDismiss: (() -> Void)?
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingShareError = false
    @State private var shareErrorMessage = ""

    init(song: Song, onPerform: @escaping () -> Void, onEdit: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.song = song
        self.onPerform = onPerform
        self.onEdit = onEdit
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let thumbnailData = song.thumbnailData,
                       let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 400)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(song.title ?? "Untitled")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let artist = song.artist {
                            Text(artist)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            if let key = song.key {
                                Label(key, systemImage: "music.note")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            if song.durationSecs > 0 {
                                let duration = song.durationSecs
                                Label(formatDuration(duration), systemImage: "clock")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        
                        if !song.tagsArray.isEmpty {
                            let tags = song.tagsArray
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        
                        if let notes = song.notes {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top)
                        }
                        
                        HStack {
                            Text("Created")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(song.createdAt ?? Date(), style: .date)
                                .font(.caption)
                            
                            if let lastOpened = song.lastOpenedAt {
                                Spacer()
                                Text("Last opened")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(lastOpened, style: .relative)
                                    .font(.caption)
                            }
                        }
                        .padding(.top)
                    }
                    .padding()
                }
                .padding(.bottom, 20)
            }
            
            Button {
                onPerform()
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Perform")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Song Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    // Edit and Share buttons for ChordLibre sheets
                    if song.isChordLibreSheet {
                        if let onEdit = onEdit {
                            Button {
                                onEdit()
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .foregroundColor(.accentColor)
                        }

                        Button {
                            shareChordsheet()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .foregroundColor(.accentColor)
                    }

                    if horizontalSizeClass == .regular, let onDismiss = onDismiss {
                        Button("Done") {
                            onDismiss()
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .alert("Share Error", isPresented: $showingShareError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareErrorMessage)
        }
    }

    private func shareChordsheet() {
        print("📤 Share button tapped for song: \(song.title ?? "Unknown")")

        guard let chordLibreSong = song.chordLibreSong else {
            print("❌ Failed to get chordLibreSong from song")
            shareErrorMessage = "Unable to load chordsheet data. The song may need to be edited and saved again."
            showingShareError = true
            return
        }

        print("✅ Got chordLibreSong, attempting export...")

        do {
            let url = try ChordLibreExporter.shared.exportChordsheet(chordLibreSong)
            print("✅ Export successful, file at: \(url.path)")

            // Present activity view controller directly
            presentActivityViewController(with: url)

            print("✅ Activity view controller presented")
        } catch {
            print("❌ Error exporting chordsheet: \(error)")
            shareErrorMessage = "Export failed: \(error.localizedDescription)"
            showingShareError = true
        }
    }

    private func presentActivityViewController(with url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // For iPad: configure popover
        if let popover = activityVC.popoverPresentationController {
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }

            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        topController.present(activityVC, animated: true) {
            print("✅ Activity view controller presented successfully")
        }
    }

    private func formatDuration(_ seconds: Int32) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - ShareSheet (used by SongDetailView and SetlistDetailView)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // For iPad: configure popover presentation
        if let popover = controller.popoverPresentationController {
            popover.sourceView = context.coordinator.sourceView
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var sourceView = UIView()
    }
}