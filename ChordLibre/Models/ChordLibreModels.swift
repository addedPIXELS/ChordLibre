//
//  ChordLibreModels.swift
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

// MARK: - ChordLibre Song Structure

/// Represents a complete ChordLibre chordsheet with sections and metadata
struct ChordLibreSong: Codable, Equatable {
    var title: String
    var artist: String?
    var key: MusicalKey
    var sections: [ChordLibreSection]
    var tempo: Int?
    var timeSignature: String?
    var capo: Int?

    /// The display key for the song (same as key property for consistency)
    var displayKey: MusicalKey { key }
}

// MARK: - Section

/// Represents a section of a song (verse, chorus, bridge, etc.)
struct ChordLibreSection: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String  // e.g., "Verse 1", "Chorus", "Bridge"
    var lines: [ChordLibreLine]

    init(id: UUID = UUID(), label: String, lines: [ChordLibreLine] = []) {
        self.id = id
        self.label = label
        self.lines = lines
    }
}

// MARK: - Line

/// Represents a single line with lyrics and an optional chord
struct ChordLibreLine: Codable, Equatable, Identifiable {
    let id: UUID
    var lyrics: String
    var chord: Chord?

    init(id: UUID = UUID(), lyrics: String, chord: Chord? = nil) {
        self.id = id
        self.lyrics = lyrics
        self.chord = chord
    }
}

// MARK: - Musical Key

/// Musical key enumeration supporting major and minor keys with all accidentals
enum MusicalKey: String, Codable, CaseIterable {
    // Major keys
    case C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B

    // Minor keys (using 'm' suffix)
    case Cm, Dbm, Dm, Ebm, Em, Fm, Gbm, Gm, Abm, Am, Bbm, Bm

    /// Returns the semitone value (0-11) for chromatic positioning
    var semitoneValue: Int {
        switch self {
        case .C, .Cm: return 0
        case .Db, .Dbm: return 1
        case .D, .Dm: return 2
        case .Eb, .Ebm: return 3
        case .E, .Em: return 4
        case .F, .Fm: return 5
        case .Gb, .Gbm: return 6
        case .G, .Gm: return 7
        case .Ab, .Abm: return 8
        case .A, .Am: return 9
        case .Bb, .Bbm: return 10
        case .B, .Bm: return 11
        }
    }

    /// Returns true if the key is major, false if minor
    var isMajor: Bool {
        !rawValue.contains("m")
    }

    /// Creates a MusicalKey from a semitone value (0-11), quality, and sharp/flat preference
    static func from(semitone: Int, major: Bool, preferSharps: Bool) -> MusicalKey {
        let normalizedSemitone = ((semitone % 12) + 12) % 12  // Ensure 0-11 range

        // Define sharp and flat orderings
        let sharpsMajor: [MusicalKey] = [.C, .Db, .D, .Eb, .E, .F, .Gb, .G, .Ab, .A, .Bb, .B]
        let sharpsMinor: [MusicalKey] = [.Cm, .Dbm, .Dm, .Ebm, .Em, .Fm, .Gbm, .Gm, .Abm, .Am, .Bbm, .Bm]

        // For simplicity, use the same ordering (most keys have standard enharmonic spellings)
        let keys = major ? sharpsMajor : sharpsMinor
        return keys[normalizedSemitone]
    }

    /// Display name for the key (same as rawValue for now)
    var displayName: String {
        rawValue
    }
}

// MARK: - Chord

/// Represents a musical chord with all its components
struct Chord: Codable, Equatable {
    var root: String           // C, D, E, F, G, A, B
    var accidental: String?    // # or b
    var quality: String?       // m, dim, aug, sus2, sus4, etc.
    var ext: String?           // 6, 7, 9, 11, 13, etc. (renamed from 'extension' which is a Swift keyword)
    var modifications: String? // b5, #9, add9, etc.
    var bass: String?          // Slash chord bass note (e.g., "/G")

    /// Returns the complete chord as a display string
    var displayString: String {
        var result = root
        if let acc = accidental { result += acc }
        if let qual = quality { result += qual }
        if let ex = ext { result += ex }
        if let mods = modifications { result += mods }
        if let b = bass { result += b }
        return result
    }

    /// Initializes a chord from its components
    init(root: String, accidental: String? = nil, quality: String? = nil, ext: String? = nil, modifications: String? = nil, bass: String? = nil) {
        self.root = root
        self.accidental = accidental
        self.quality = quality
        self.ext = ext
        self.modifications = modifications
        self.bass = bass
    }
}

// MARK: - Previous Key History

/// Represents a key that was previously performed, with timestamp
struct PreviousKey: Codable, Equatable {
    let key: MusicalKey
    let performedAt: Date

    init(key: MusicalKey, performedAt: Date = Date()) {
        self.key = key
        self.performedAt = performedAt
    }
}
