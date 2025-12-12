//
//  ChordLibreExporter.swift
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
import UniformTypeIdentifiers

/// Service for exporting and importing ChordLibre chordsheets and setlists
class ChordLibreExporter {
    static let shared = ChordLibreExporter()

    private init() {}

    // MARK: - Export Single Chordsheet

    /// Export a ChordLibre song to a .chordlibre file
    /// - Parameter song: The ChordLibreSong to export
    /// - Returns: URL to the temporary file
    func exportChordsheet(_ song: ChordLibreSong) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(song)

        // Create temporary file
        let fileName = sanitizeFilename(song.title) + ".chordlibre"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try jsonData.write(to: tempURL)

        return tempURL
    }

    // MARK: - Import Single Chordsheet

    /// Import a ChordLibre song from a .chordlibre file
    /// - Parameter url: URL to the .chordlibre file
    /// - Returns: The imported ChordLibreSong
    func importChordsheet(from url: URL) throws -> ChordLibreSong {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let song = try decoder.decode(ChordLibreSong.self, from: data)
        return song
    }

    // MARK: - Export Setlist with Songs

    /// Export a setlist with all its songs to a .chordlibresetlist bundle
    /// - Parameters:
    ///   - setlist: The Setlist entity
    ///   - dataStore: DataStore for accessing songs
    /// - Returns: URL to the temporary bundle directory
    func exportSetlist(_ setlist: Setlist, dataStore: DataStore) throws -> URL {
        let setlistName = sanitizeFilename(setlist.name ?? "Untitled Setlist")

        // Create a temporary directory for the bundle
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(setlistName + ".chordlibresetlist")

        // Remove if exists
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            try FileManager.default.removeItem(at: bundleURL)
        }

        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        // Create setlist metadata
        let metadata = SetlistMetadata(
            name: setlist.name ?? "Untitled",
            venue: setlist.venue,
            eventDate: setlist.eventDate,
            notes: setlist.notes,
            sets: setlist.setsArray.map { set in
                SetMetadata(
                    name: set.name ?? "Untitled Set",
                    position: Int(set.position),
                    notes: set.notes,
                    targetDuration: set.targetDuration > 0 ? Int(set.targetDuration) : nil,
                    songFilenames: set.setItemsArray.compactMap { setItem in
                        guard let song = setItem.song else { return nil }
                        return sanitizeFilename(song.title ?? "Untitled") + ".chordlibre"
                    }
                )
            }
        )

        // Save metadata
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let metadataData = try encoder.encode(metadata)
        let metadataURL = bundleURL.appendingPathComponent("setlist.json")
        try metadataData.write(to: metadataURL)

        // Create songs directory
        let songsURL = bundleURL.appendingPathComponent("songs")
        try FileManager.default.createDirectory(at: songsURL, withIntermediateDirectories: true)

        // Export all ChordLibre songs in the setlist
        var exportedSongs: Swift.Set<String> = []

        for set in setlist.setsArray {
            for setItem in set.setItemsArray {
                guard let song = setItem.song,
                      song.isChordLibreSheet,
                      let chordLibreSong = song.chordLibreSong else { continue }

                let filename = sanitizeFilename(song.title ?? "Untitled") + ".chordlibre"

                // Avoid duplicates
                if exportedSongs.contains(filename) { continue }
                exportedSongs.insert(filename)

                let songData = try encoder.encode(chordLibreSong)
                let songURL = songsURL.appendingPathComponent(filename)
                try songData.write(to: songURL)
            }
        }

        // Create a README
        let readme = """
        ChordLibre Setlist: \(metadata.name)

        This is a ChordLibre setlist bundle containing:
        - setlist.json: Setlist metadata and structure
        - songs/: ChordLibre chordsheet files

        To import:
        1. Open ChordLibre app
        2. Tap the + button
        3. Select "Import Setlist"
        4. Choose this .chordlibresetlist file

        All songs will be imported and the setlist will be recreated.
        """

        let readmeURL = bundleURL.appendingPathComponent("README.txt")
        try readme.write(to: readmeURL, atomically: true, encoding: .utf8)

        return bundleURL
    }

    // MARK: - Import Setlist

    /// Import a setlist bundle
    /// - Parameters:
    ///   - url: URL to the .chordlibresetlist bundle
    ///   - dataStore: DataStore for creating songs and setlist
    /// - Returns: The created Setlist entity
    @discardableResult
    @MainActor
    func importSetlist(from url: URL, dataStore: DataStore) throws -> Setlist {
        // Read metadata
        let metadataURL = url.appendingPathComponent("setlist.json")
        let metadataData = try Data(contentsOf: metadataURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata = try decoder.decode(SetlistMetadata.self, from: metadataData)

        // Create setlist
        let setlist = dataStore.createSetlist(
            name: metadata.name,
            venue: metadata.venue,
            eventDate: metadata.eventDate,
            notes: metadata.notes
        )

        let songsURL = url.appendingPathComponent("songs")
        var importedSongs: [String: Song] = [:]

        // Import all songs first
        for setMetadata in metadata.sets {
            for filename in setMetadata.songFilenames {
                // Skip if already imported
                if importedSongs[filename] != nil { continue }

                let songURL = songsURL.appendingPathComponent(filename)

                // Import the chordsheet
                let chordLibreSong = try importChordsheet(from: songURL)
                let song = dataStore.createChordLibreSong(chordLibreSong: chordLibreSong)
                importedSongs[filename] = song
            }
        }

        // Create sets and add songs in order
        for setMetadata in metadata.sets.sorted(by: { $0.position < $1.position }) {
            let set = dataStore.createSet(in: setlist, name: setMetadata.name)
            set.notes = setMetadata.notes
            if let duration = setMetadata.targetDuration {
                set.targetDuration = Int32(duration)
            }

            // Add songs to set in order
            for filename in setMetadata.songFilenames {
                if let song = importedSongs[filename] {
                    dataStore.addSongToSet(song, set: set)
                }
            }
        }

        dataStore.save()
        return setlist
    }

    // MARK: - Helper Methods

    /// Sanitize filename by removing invalid characters
    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidCharacters).joined(separator: "-")
    }
}

// MARK: - Metadata Structures

struct SetlistMetadata: Codable {
    let name: String
    let venue: String?
    let eventDate: Date?
    let notes: String?
    let sets: [SetMetadata]
}

struct SetMetadata: Codable {
    let name: String
    let position: Int
    let notes: String?
    let targetDuration: Int?
    let songFilenames: [String]
}
