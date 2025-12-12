//
//  ChordLibreEditor.swift
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

struct ChordLibreEditor: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: DataStore

    @State private var song: ChordLibreSong
    @State private var editingMetadata = false
    let existingSong: Song?

    init(song: ChordLibreSong, existingSong: Song? = nil) {
        _song = State(initialValue: song)
        self.existingSong = existingSong
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Info") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.headline)
                            if let artist = song.artist {
                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text("Key: \(song.key.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Edit") {
                            editingMetadata = true
                        }
                    }
                }

                ForEach(song.sections.indices, id: \.self) { sectionIndex in
                    sectionEditor(at: sectionIndex)
                }
                .onDelete { indexSet in
                    song.sections.remove(atOffsets: indexSet)
                }
                .onMove { from, to in
                    song.sections.move(fromOffsets: from, toOffset: to)
                }

                Section {
                    Button {
                        addSection()
                    } label: {
                        Label("Add Section", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Edit Chordsheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSong()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $editingMetadata) {
                MetadataEditor(song: $song)
            }
        }
    }

    @ViewBuilder
    private func sectionEditor(at index: Int) -> some View {
        Section {
            TextField("Section Name", text: $song.sections[index].label)
                .font(.headline)

            ForEach(song.sections[index].lines.indices, id: \.self) { lineIndex in
                lineEditor(sectionIndex: index, lineIndex: lineIndex)
            }
            .onDelete { indexSet in
                song.sections[index].lines.remove(atOffsets: indexSet)
            }
            .onMove { from, to in
                song.sections[index].lines.move(fromOffsets: from, toOffset: to)
            }

            Button {
                addLine(toSection: index)
            } label: {
                Label("Add Line", systemImage: "plus.circle")
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func lineEditor(sectionIndex: Int, lineIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Lyrics", text: $song.sections[sectionIndex].lines[lineIndex].lyrics, axis: .vertical)
                .font(.body)

            HStack {
                TextField("Chord (optional)", text: Binding(
                    get: {
                        song.sections[sectionIndex].lines[lineIndex].chord?.displayString ?? ""
                    },
                    set: { newValue in
                        if newValue.isEmpty {
                            song.sections[sectionIndex].lines[lineIndex].chord = nil
                        } else {
                            if let chord = try? TranspositionEngine.shared.parseChord(newValue) {
                                song.sections[sectionIndex].lines[lineIndex].chord = chord
                            }
                        }
                    }
                ))
                .font(.body)
                .textInputAutocapitalization(.characters)

                if song.sections[sectionIndex].lines[lineIndex].chord != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func addSection() {
        let newSection = ChordLibreSection(
            label: "New Section",
            lines: [ChordLibreLine(lyrics: "", chord: nil)]
        )
        song.sections.append(newSection)
    }

    private func addLine(toSection index: Int) {
        let newLine = ChordLibreLine(lyrics: "", chord: nil)
        song.sections[index].lines.append(newLine)
    }

    private func saveSong() {
        if let existing = existingSong {
            // Update existing song
            existing.title = song.title
            existing.artist = song.artist
            existing.key = song.key.rawValue
            existing.chordLibreSong = song
            existing.updatedAt = Date()
            dataStore.save()
        } else {
            // Create new song
            _ = dataStore.createChordLibreSong(chordLibreSong: song)
        }

        dataStore.loadSongs()
        dismiss()
    }
}

// MARK: - Metadata Editor

struct MetadataEditor: View {
    @Binding var song: ChordLibreSong
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Title", text: $song.title)
                    TextField("Artist", text: Binding(
                        get: { song.artist ?? "" },
                        set: { song.artist = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Musical Details") {
                    Picker("Key", selection: $song.key) {
                        ForEach(MusicalKey.allCases, id: \.self) { key in
                            Text(key.displayName).tag(key)
                        }
                    }

                    HStack {
                        Text("Tempo (BPM)")
                        TextField("", value: Binding(
                            get: { song.tempo ?? 0 },
                            set: { song.tempo = $0 > 0 ? $0 : nil }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                    }

                    TextField("Time Signature", text: Binding(
                        get: { song.timeSignature ?? "" },
                        set: { song.timeSignature = $0.isEmpty ? nil : $0 }
                    ))
                    .placeholder(when: song.timeSignature == nil || song.timeSignature!.isEmpty) {
                        Text("e.g., 4/4").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Capo")
                        TextField("", value: Binding(
                            get: { song.capo ?? 0 },
                            set: { song.capo = $0 > 0 ? $0 : nil }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Song Metadata")
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

// MARK: - TextField Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleSong = ChordLibreSong(
        title: "Sample Song",
        artist: "Sample Artist",
        key: .C,
        sections: [
            ChordLibreSection(label: "Verse 1", lines: [
                ChordLibreLine(lyrics: "Sample lyrics", chord: try? TranspositionEngine.shared.parseChord("C"))
            ])
        ]
    )

    return ChordLibreEditor(song: sampleSong)
        .environmentObject(DataStore.shared)
}
