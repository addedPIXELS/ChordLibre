//
//  ChordsheetCreatorView.swift
//  ChordLibre
//
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

struct ChordsheetCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: DataStore
    @State private var title = ""
    @State private var artist = ""
    @State private var selectedKey = MusicalKey.C
    @State private var showingEditor = false
    @State private var createdSong: ChordLibreSong?

    var body: some View {
        NavigationView {
            Form {
                Section("Song Information") {
                    TextField("Title", text: $title)
                    TextField("Artist (optional)", text: $artist)
                    Picker("Key", selection: $selectedKey) {
                        ForEach(MusicalKey.allCases, id: \.self) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                }

                Section {
                    Text("A new chordsheet will be created with one empty section. You can add sections and lines in the editor.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Chordsheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChordsheet()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let song = createdSong {
                    ChordLibreEditor(song: song, existingSong: nil)
                        .environmentObject(dataStore)
                }
            }
        }
    }

    private func createChordsheet() {
        let newSong = ChordLibreSong(
            title: title,
            artist: artist.isEmpty ? nil : artist,
            key: selectedKey,
            sections: [
                ChordLibreSection(label: "Verse 1", lines: [
                    ChordLibreLine(lyrics: "", chord: nil)
                ])
            ]
        )

        createdSong = newSong
        showingEditor = true
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ChordsheetCreatorView()
        .environmentObject(DataStore.shared)
}
