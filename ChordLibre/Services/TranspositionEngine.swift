//
//  TranspositionEngine.swift
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

import Foundation

/// Singleton service for parsing and transposing musical chords
class TranspositionEngine {
    static let shared = TranspositionEngine()

    private init() {}

    // MARK: - Chord Parsing

    /// Regex pattern for parsing chord symbols
    /// Captures: root, accidental, quality+ext+mods, slash bass
    private let chordPattern = #"^([A-G])([#b])?([^/]*)(?:/([A-G][#b]?))?$"#

    /// Parse a chord string into a Chord object
    /// - Parameter input: The chord string (e.g., "Dm7b5", "C/G", "F#")
    /// - Returns: A Chord object with parsed components
    /// - Throws: ChordParseError if the chord cannot be parsed
    func parseChord(_ input: String) throws -> Chord {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ChordParseError.empty
        }

        guard let regex = try? NSRegularExpression(pattern: chordPattern) else {
            throw ChordParseError.invalidPattern
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range) else {
            throw ChordParseError.noMatch(trimmed)
        }

        // Extract root (always present)
        guard let rootRange = Range(match.range(at: 1), in: trimmed) else {
            throw ChordParseError.noMatch(trimmed)
        }
        let root = String(trimmed[rootRange])

        // Extract accidental (optional)
        var accidental: String?
        if match.range(at: 2).location != NSNotFound,
           let accRange = Range(match.range(at: 2), in: trimmed) {
            accidental = String(trimmed[accRange])
        }

        // Extract quality/extension/modifications (everything between root and slash)
        var qualityAndExt: String?
        if match.range(at: 3).location != NSNotFound,
           let qualExtRange = Range(match.range(at: 3), in: trimmed) {
            let extracted = String(trimmed[qualExtRange])
            qualityAndExt = extracted.isEmpty ? nil : extracted
        }

        // Extract slash bass (optional)
        var bass: String?
        if match.range(at: 4).location != NSNotFound,
           let bassRange = Range(match.range(at: 4), in: trimmed) {
            bass = "/" + String(trimmed[bassRange])
        }

        // Parse quality, extension, and modifications from the combined string
        let (quality, ext, modifications) = parseQualityExtension(qualityAndExt ?? "")

        return Chord(
            root: root,
            accidental: accidental,
            quality: quality,
            ext: ext,
            modifications: modifications,
            bass: bass
        )
    }

    /// Parse and transpose multiple space-separated chords
    /// - Parameters:
    ///   - input: Space-separated chord string (e.g., "C G Am")
    ///   - semitones: Number of semitones to transpose
    ///   - preferSharps: Whether to prefer sharps over flats
    /// - Returns: Transposed chord string with same spacing
    func transposeChordString(_ input: String, semitones: Int, preferSharps: Bool) -> String {
        // Split on whitespace, preserving spacing
        let components = input.components(separatedBy: " ")

        let transposedChords = components.map { component in
            let trimmed = component.trimmingCharacters(in: .whitespaces)

            // Empty components (from multiple spaces) - preserve
            guard !trimmed.isEmpty else { return component }

            // Try to parse and transpose
            if let chord = try? parseChord(trimmed) {
                let transposed = transpose(chord: chord, semitones: semitones, preferSharps: preferSharps)
                return transposed.displayString
            } else {
                // If parsing fails, return original
                return trimmed
            }
        }

        return transposedChords.joined(separator: " ")
    }

    /// Parse the quality/extension/modifications portion of a chord
    /// This is a simplified parser that preserves the full string for now
    private func parseQualityExtension(_ input: String) -> (quality: String?, ext: String?, modifications: String?) {
        guard !input.isEmpty else {
            return (nil, nil, nil)
        }

        // For simplicity, we'll keep the entire suffix together
        // A more sophisticated parser could split this into quality, extension, and modifications
        // For now, we treat common patterns:
        // - Single 'm' or 'min' -> quality
        // - Numbers (6, 7, 9, 11, 13) -> extension
        // - Everything else -> modifications

        var quality: String?
        var ext: String?
        var modifications: String?

        // Check for minor quality
        if input.hasPrefix("m") || input.hasPrefix("min") {
            if input.hasPrefix("maj") {
                // maj7, maj9, etc. - quality is "maj"
                quality = "maj"
                let remainder = String(input.dropFirst(3))
                if !remainder.isEmpty {
                    ext = remainder
                }
            } else {
                // m, m7, m7b5, etc. - quality is "m"
                quality = "m"
                let remainder = String(input.dropFirst(1))
                if !remainder.isEmpty {
                    // Could be extension + modifications
                    ext = remainder
                }
            }
        } else if input.hasPrefix("dim") {
            quality = "dim"
            let remainder = String(input.dropFirst(3))
            if !remainder.isEmpty {
                ext = remainder
            }
        } else if input.hasPrefix("aug") || input.hasPrefix("+") {
            quality = input.hasPrefix("aug") ? "aug" : "+"
            let remainder = String(input.dropFirst(input.hasPrefix("aug") ? 3 : 1))
            if !remainder.isEmpty {
                ext = remainder
            }
        } else if input.hasPrefix("sus") {
            // sus2, sus4
            if input.count >= 4 {
                quality = String(input.prefix(4)) // "sus2" or "sus4"
                let remainder = String(input.dropFirst(4))
                if !remainder.isEmpty {
                    ext = remainder
                }
            } else {
                quality = input
            }
        } else {
            // No explicit quality - just extension/modifications
            ext = input
        }

        return (quality, ext, modifications)
    }

    // MARK: - Transposition

    /// Transpose a chord by a given number of semitones
    /// - Parameters:
    ///   - chord: The chord to transpose
    ///   - semitones: Number of semitones to transpose (positive = up, negative = down)
    ///   - preferSharps: Whether to prefer sharp notation over flats
    /// - Returns: A new transposed chord
    func transpose(chord: Chord, semitones: Int, preferSharps: Bool) -> Chord {
        // Transpose root note
        let transposedRoot = transposeNote(
            root: chord.root,
            accidental: chord.accidental,
            semitones: semitones,
            preferSharps: preferSharps
        )

        var transposedChord = chord
        transposedChord.root = transposedRoot.root
        transposedChord.accidental = transposedRoot.accidental

        // Transpose bass note if present
        if let bass = chord.bass, bass.count > 1 {
            let bassString = String(bass.dropFirst()) // Remove leading "/"
            let bassRoot = String(bassString.prefix(1))
            let bassAcc = bassString.count > 1 ? String(bassString.dropFirst().prefix(1)) : nil

            let transposedBass = transposeNote(
                root: bassRoot,
                accidental: bassAcc,
                semitones: semitones,
                preferSharps: preferSharps
            )

            var bassNotation = transposedBass.root
            if let acc = transposedBass.accidental {
                bassNotation += acc
            }
            transposedChord.bass = "/" + bassNotation
        }

        return transposedChord
    }

    /// Transpose an entire song by a given number of semitones
    /// - Parameters:
    ///   - song: The song to transpose
    ///   - semitones: Number of semitones to transpose
    /// - Returns: A new transposed song
    func transpose(song: ChordLibreSong, semitones: Int) -> ChordLibreSong {
        var transposed = song

        // Calculate new key
        let currentSemitone = song.key.semitoneValue
        let newSemitone = (currentSemitone + semitones + 12) % 12
        let preferSharps = shouldPreferSharps(targetSemitone: newSemitone)
        let newKey = MusicalKey.from(
            semitone: newSemitone,
            major: song.key.isMajor,
            preferSharps: preferSharps
        )
        transposed.key = newKey

        // Transpose all chords in all sections
        transposed.sections = song.sections.map { section in
            var newSection = section
            newSection.lines = section.lines.map { line in
                var newLine = line
                if let chords = line.chords, !chords.isEmpty {
                    newLine.chords = transposeChordString(
                        chords,
                        semitones: semitones,
                        preferSharps: preferSharps
                    )
                }
                return newLine
            }
            return newSection
        }

        return transposed
    }

    // MARK: - Helper Methods

    /// Transpose a note by semitones
    private func transposeNote(
        root: String,
        accidental: String?,
        semitones: Int,
        preferSharps: Bool
    ) -> (root: String, accidental: String?) {
        // Map note names to semitone values (C=0)
        let noteMap: [String: Int] = [
            "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
        ]

        // Sharp and flat orderings
        let sharpsOrder = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let flatsOrder = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

        // Get current semitone value
        guard let baseSemitone = noteMap[root] else {
            // If root not found, return as-is
            return (root, accidental)
        }

        let accidentalOffset: Int
        if accidental == "#" {
            accidentalOffset = 1
        } else if accidental == "b" {
            accidentalOffset = -1
        } else {
            accidentalOffset = 0
        }

        let currentSemitone = (baseSemitone + accidentalOffset + 12) % 12
        let newSemitone = (currentSemitone + semitones + 12) % 12

        // Select sharp or flat notation
        let noteArray = preferSharps ? sharpsOrder : flatsOrder
        let newNoteString = noteArray[newSemitone]

        // Parse the result
        if newNoteString.count == 1 {
            return (root: newNoteString, accidental: nil)
        } else {
            return (root: String(newNoteString.prefix(1)), accidental: String(newNoteString.suffix(1)))
        }
    }

    /// Determine whether to prefer sharps based on the target semitone
    /// Keys with more sharps: G, D, A, E, B, F# (semitones: 7, 2, 9, 4, 11, 6)
    /// Keys with more flats: F, Bb, Eb, Ab, Db, Gb (semitones: 5, 10, 3, 8, 1, 6)
    private func shouldPreferSharps(targetSemitone: Int) -> Bool {
        let sharpKeys: Swift.Set<Int> = [7, 2, 9, 4, 11, 6]
        return sharpKeys.contains(targetSemitone)
    }

    // MARK: - Error Types

    enum ChordParseError: LocalizedError {
        case empty
        case invalidPattern
        case noMatch(String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "Chord string is empty"
            case .invalidPattern:
                return "Invalid regex pattern"
            case .noMatch(let chord):
                return "Could not parse chord: \(chord)"
            }
        }
    }
}
