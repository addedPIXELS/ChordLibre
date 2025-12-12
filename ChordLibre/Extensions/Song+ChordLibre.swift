//
//  Song+ChordLibre.swift
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
import CoreData

// MARK: - ChordLibre Support Extension

extension Song {
    /// Returns true if this song is a ChordLibre native chordsheet
    var isChordLibreSheet: Bool {
        songType == "chordlibre"
    }

    /// Returns true if this song is a PDF
    var isPDF: Bool {
        songType == "pdf" || songType == nil
    }

    /// Gets or sets the ChordLibre song data, encoding/decoding from JSON
    var chordLibreSong: ChordLibreSong? {
        get {
            guard let jsonString = chordLibreJSON,
                  let jsonData = jsonString.data(using: .utf8) else {
                return nil
            }

            let decoder = JSONDecoder()
            do {
                return try decoder.decode(ChordLibreSong.self, from: jsonData)
            } catch {
                print("❌ Error decoding ChordLibreSong for song '\(title ?? "Unknown")':")
                print("   Error: \(error)")
                if let decodingError = error as? DecodingError {
                    print("   Details: \(decodingError.localizedDescription)")
                }
                print("   JSON preview: \(jsonString.prefix(200))...")
                return nil
            }
        }
        set {
            guard let song = newValue else {
                chordLibreJSON = nil
                return
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            do {
                let jsonData = try encoder.encode(song)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    chordLibreJSON = jsonString
                }
            } catch {
                print("Error encoding ChordLibreSong: \(error)")
            }
        }
    }

    /// Gets or sets the array of previous keys performed
    var previousKeys: [PreviousKey] {
        get {
            guard let data = previousKeysPerformed as? Data else {
                return []
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                return try decoder.decode([PreviousKey].self, from: data)
            } catch {
                print("Error decoding previousKeys: \(error)")
                return []
            }
        }
        set {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            do {
                let data = try encoder.encode(newValue)
                previousKeysPerformed = data as NSObject
            } catch {
                print("Error encoding previousKeys: \(error)")
            }
        }
    }

    /// Records that a key was performed at the current time
    /// Maintains a maximum of 20 entries
    func recordKeyPerformed(_ key: MusicalKey) {
        var keys = previousKeys
        keys.append(PreviousKey(key: key, performedAt: Date()))

        // Keep only last 20 entries
        if keys.count > 20 {
            keys = Array(keys.suffix(20))
        }

        previousKeys = keys
    }
}
