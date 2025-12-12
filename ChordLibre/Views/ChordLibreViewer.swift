//
//  ChordLibreViewer.swift
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

struct ChordLibreViewer: View {
    let song: Song
    @State private var transposedSong: ChordLibreSong
    @State private var currentTransposition: Int = 0
    @State private var showPreviousKeys = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: DataStore

    init(song: Song) {
        self.song = song
        // Initialize with the original song or a default if parsing fails
        _transposedSong = State(initialValue: song.chordLibreSong ?? ChordLibreSong(
            title: song.title ?? "Unknown",
            artist: song.artist,
            key: .C,
            sections: []
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(transposedSong.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 100) // Space for top toolbar
                .padding(.bottom, 50)
            }
            .onTapGesture {
                toggleControls()
            }

            // Top toolbar
            if showControls {
                VStack {
                    topToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .statusBar(hidden: !showControls)
        .onAppear {
            dataStore.updateSongLastOpened(song)
            UIApplication.shared.isIdleTimerDisabled = true
            resetControlsTimer()
        }
        .onDisappear {
            // Record the key performed if transposed
            if currentTransposition != 0 {
                song.recordKeyPerformed(transposedSong.key)
                dataStore.save()
            }
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showPreviousKeys) {
            PreviousKeysView(song: song) { selectedKey in
                transposeToKey(selectedKey)
            }
        }
    }

    // MARK: - Top Toolbar

    @ViewBuilder
    private var topToolbar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }

                Spacer()

                // Song info
                VStack(spacing: 4) {
                    Text(transposedSong.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    if let artist = transposedSong.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 2)
                    }
                }

                Spacer()

                // Transposition controls
                HStack(spacing: 12) {
                    Button {
                        transposeDown()
                        resetControlsTimer()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }

                    VStack(spacing: 2) {
                        Text(transposedSong.key.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        if currentTransposition != 0 {
                            Text("\(currentTransposition > 0 ? "+" : "")\(currentTransposition)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .shadow(radius: 2)
                        }
                    }
                    .frame(minWidth: 50)

                    Button {
                        transposeUp()
                        resetControlsTimer()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }

                    Menu {
                        Button {
                            resetTransposition()
                        } label: {
                            Label("Reset to Original", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            showPreviousKeys = true
                        } label: {
                            Label("Previous Keys", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.8), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            )
        }
    }

    // MARK: - Section View

    @ViewBuilder
    private func sectionView(_ section: ChordLibreSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section label
            Text(section.label)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.yellow)
                .padding(.bottom, 4)

            // Lines
            ForEach(section.lines) { line in
                lineView(line)
            }
        }
    }

    // MARK: - Line View

    @ViewBuilder
    private func lineView(_ line: ChordLibreLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Lyrics (left-aligned)
            Text(line.lyrics)
                .font(.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Chord (right-aligned)
            if let chord = line.chord {
                Spacer(minLength: 16)
                Text(chord.displayString)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Transposition Methods

    private func transposeUp() {
        guard let originalSong = song.chordLibreSong else { return }
        currentTransposition += 1
        transposedSong = TranspositionEngine.shared.transpose(
            song: originalSong,
            semitones: currentTransposition
        )
    }

    private func transposeDown() {
        guard let originalSong = song.chordLibreSong else { return }
        currentTransposition -= 1
        transposedSong = TranspositionEngine.shared.transpose(
            song: originalSong,
            semitones: currentTransposition
        )
    }

    private func resetTransposition() {
        guard let originalSong = song.chordLibreSong else { return }
        currentTransposition = 0
        transposedSong = originalSong
    }

    private func transposeToKey(_ targetKey: MusicalKey) {
        guard let originalSong = song.chordLibreSong else { return }

        // Calculate semitone difference
        let currentSemitone = originalSong.key.semitoneValue
        let targetSemitone = targetKey.semitoneValue
        let semitones = (targetSemitone - currentSemitone + 12) % 12

        currentTransposition = semitones
        transposedSong = TranspositionEngine.shared.transpose(
            song: originalSong,
            semitones: semitones
        )
    }

    // MARK: - Controls Timer

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        if showControls {
            resetControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleSong = ChordLibreSong(
        title: "Feelings",
        artist: "Morris Albert",
        key: .F,
        sections: [
            ChordLibreSection(label: "Chorus", lines: [
                ChordLibreLine(lyrics: "Feelings, nothing more than feelings", chord: try? TranspositionEngine.shared.parseChord("F")),
                ChordLibreLine(lyrics: "Trying to forget my feelings of love", chord: try? TranspositionEngine.shared.parseChord("Fm7")),
            ]),
            ChordLibreSection(label: "Verse 1", lines: [
                ChordLibreLine(lyrics: "Teardrops rolling down on my face", chord: try? TranspositionEngine.shared.parseChord("Bb")),
                ChordLibreLine(lyrics: "Trying to forget my feelings of love", chord: try? TranspositionEngine.shared.parseChord("Am7")),
            ])
        ]
    )

    // Create a mock Song entity for preview
    // Note: This is simplified for preview purposes
    return ChordLibreViewer(song: Song())
        .environmentObject(DataStore.shared)
}
