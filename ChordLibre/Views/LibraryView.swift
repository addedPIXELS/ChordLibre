//
//  LibraryView.swift
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

struct LibraryView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedSong: Song?
    @State private var searchText = ""
    @State private var sortOption: DataStore.SortOption = .title
    @State private var isGridView = false
    @State private var multiSelectMode = false
    @State private var selectedSongs = Swift.Set<Song>()
    @State private var songToEdit: Song?
    @State private var songToAddToSetlist: Song?
    @State private var showingSetlistPicker = false
    
    let filter: NavigationTab
    
    init(filter: NavigationTab, selectedSong: Binding<Song?>) {
        self.filter = filter
        self._selectedSong = selectedSong
    }
    
    var filteredSongs: [Song] {
        var songs = dataStore.songs
        
        if !searchText.isEmpty {
            songs = songs.filter { song in
                (song.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (song.artist?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                song.tagsArray.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        switch filter {
        case .byTitle:
            songs.sort { ($0.title ?? "") < ($1.title ?? "") }
        case .byArtist:
            songs.sort { 
                if $0.artist == $1.artist {
                    return ($0.title ?? "") < ($1.title ?? "")
                }
                return ($0.artist ?? "") < ($1.artist ?? "")
            }
        case .recent:
            songs.sort { 
                ($0.lastOpenedAt ?? Date.distantPast) > ($1.lastOpenedAt ?? Date.distantPast)
            }
        default:
            break
        }
        
        return songs
    }
    
    var groupedByArtist: [(String, [Song])] {
        let songs = filteredSongs
        let grouped = Dictionary(grouping: songs) { $0.artist ?? "Unknown Artist" }
        return grouped.sorted { 
            $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending 
        }.map { ($0.key, $0.value.sorted { 
            ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending 
        }) }
    }
    
    var groupedByTitle: [(String, [Song])] {
        let songs = filteredSongs
        let grouped = Dictionary(grouping: songs) { song in
            let title = song.title ?? ""
            let firstChar = title.isEmpty ? "#" : String(title.prefix(1).uppercased())
            return firstChar.rangeOfCharacter(from: CharacterSet.letters) != nil ? firstChar : "#"
        }
        
        return grouped.sorted { 
            if $0.key == "#" { return false }
            if $1.key == "#" { return true }
            return $0.key < $1.key 
        }.map { ($0.key, $0.value.sorted { ($0.title ?? "") < ($1.title ?? "") }) }
    }
    
    
    var body: some View {
        Group {
            if isGridView {
                gridView
            } else {
                listView
            }
        }
        .searchable(text: $searchText, prompt: "Search songs, artists, or tags")
        .navigationTitle(filter.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(DataStore.SortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: sortIcon(for: option))
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                
                Button {
                    isGridView.toggle()
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                }
                
                Button {
                    multiSelectMode.toggle()
                    if !multiSelectMode {
                        selectedSongs.removeAll()
                    }
                } label: {
                    Image(systemName: multiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
        }
        .onChange(of: sortOption) { _, newValue in
            dataStore.sortOption = newValue
        }
        .sheet(item: $songToEdit) { song in
            EditSongMetadataView(song: song)
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingSetlistPicker) {
            if let song = songToAddToSetlist {
                SetlistPickerView(song: song)
                    .environmentObject(dataStore)
            }
        }
    }
    
    @ViewBuilder
    private var listView: some View {
        switch filter {
        case .byArtist:
            artistGroupedListView
        case .byTitle:
            titleOnlyListView
        default:
            standardListView
        }
    }
    
    @ViewBuilder
    private var standardListView: some View {
        List(selection: multiSelectMode ? $selectedSongs : nil) {
            ForEach(filteredSongs) { song in
                Button(action: {
                    if multiSelectMode {
                        if selectedSongs.contains(song) {
                            selectedSongs.remove(song)
                        } else {
                            selectedSongs.insert(song)
                        }
                    } else {
                        selectedSong = song
                    }
                }) {
                    SongRowView(song: song)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    songContextMenu(for: song)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete { indexSet in
                deleteSongs(at: indexSet)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    @ViewBuilder
    private var artistGroupedListView: some View {
        List(selection: multiSelectMode ? $selectedSongs : nil) {
            ForEach(groupedByArtist, id: \.0) { artistGroup in
                let (artistName, songs) = artistGroup
                Section(artistName) {
                    ForEach(songs) { song in
                        Button(action: {
                            if multiSelectMode {
                                if selectedSongs.contains(song) {
                                    selectedSongs.remove(song)
                                } else {
                                    selectedSongs.insert(song)
                                }
                            } else {
                                selectedSong = song
                            }
                        }) {
                            SongRowView(song: song, hideArtist: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            songContextMenu(for: song)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { indexSet in
                        deleteSongsFromGroup(artistGroup: songs, at: indexSet)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private var titleOnlyListView: some View {
        List(selection: multiSelectMode ? $selectedSongs : nil) {
            ForEach(groupedByTitle, id: \.0) { letterGroup in
                let (letter, songs) = letterGroup
                Section(letter) {
                    ForEach(songs) { song in
                        Button(action: {
                            if multiSelectMode {
                                if selectedSongs.contains(song) {
                                    selectedSongs.remove(song)
                                } else {
                                    selectedSongs.insert(song)
                                }
                            } else {
                                selectedSong = song
                            }
                        }) {
                            SongRowView(song: song, hideArtist: false)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            songContextMenu(for: song)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { indexSet in
                        deleteSongsFromTitleGroup(letterGroup: songs, at: indexSet)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    @ViewBuilder
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))], spacing: 20) {
                ForEach(filteredSongs) { song in
                    Button(action: {
                        if multiSelectMode {
                            if selectedSongs.contains(song) {
                                selectedSongs.remove(song)
                            } else {
                                selectedSongs.insert(song)
                            }
                        } else {
                            selectedSong = song
                        }
                    }) {
                        SongGridItemView(song: song)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        songContextMenu(for: song)
                    }
                        .overlay(alignment: .topTrailing) {
                            if multiSelectMode && selectedSongs.contains(song) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .padding(8)
                            }
                        }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func songContextMenu(for song: Song) -> some View {
        Button {
            addToSetlist(song)
        } label: {
            Label("Add to Setlist", systemImage: "plus.rectangle.on.folder")
        }
        
        Button {
            duplicateSong(song)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Button {
            editSongMetadata(song)
        } label: {
            Label("Edit Metadata", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive) {
            dataStore.deleteSong(song)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func sortIcon(for option: DataStore.SortOption) -> String {
        switch option {
        case .title: return "textformat"
        case .artist: return "person"
        case .recent: return "clock"
        case .created: return "calendar"
        }
    }
    
    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let song = filteredSongs[index]
            dataStore.deleteSong(song)
        }
    }
    
    private func deleteSongsFromGroup(artistGroup: [Song], at offsets: IndexSet) {
        for index in offsets {
            let song = artistGroup[index]
            dataStore.deleteSong(song)
        }
    }
    
    private func addToSetlist(_ song: Song) {
        songToAddToSetlist = song
        showingSetlistPicker = true
    }
    
    private func duplicateSong(_ song: Song) {
        guard let context = song.managedObjectContext else { return }
        
        let newSong = Song(context: context)
        newSong.id = UUID()
        newSong.title = "\(song.title ?? "Untitled") (Copy)"
        newSong.artist = song.artist
        newSong.key = song.key
        newSong.tags = song.tags
        newSong.durationSecs = song.durationSecs
        newSong.notes = song.notes
        newSong.pdfData = song.pdfData
        newSong.thumbnailData = song.thumbnailData
        newSong.createdAt = Date()
        newSong.updatedAt = Date()
        
        dataStore.save()
        dataStore.loadSongs()
    }
    
    private func editSongMetadata(_ song: Song) {
        songToEdit = song
    }
    
    private func deleteSongsFromTitleGroup(letterGroup: [Song], at offsets: IndexSet) {
        for index in offsets {
            dataStore.deleteSong(letterGroup[index])
        }
        dataStore.loadSongs()
    }
}


struct SongRowView: View {
    let song: Song
    let hideArtist: Bool
    @EnvironmentObject var dataStore: DataStore
    
    init(song: Song, hideArtist: Bool = false) {
        self.song = song
        self.hideArtist = hideArtist
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let thumbnailData = song.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 80)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                
                if !hideArtist, let artist = song.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    if let key = song.key {
                        Text(key)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if song.durationSecs > 0 {
                        Text(formatDuration(song.durationSecs))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !song.tagsArray.isEmpty {
                        let tags = song.tagsArray
                        ForEach(tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            
            Spacer()
            
            if let lastOpened = song.lastOpenedAt {
                Text(relativeDateString(lastOpened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: Int32) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SongGridItemView: View {
    let song: Song
    
    var body: some View {
        VStack(spacing: 8) {
            if let thumbnailData = song.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 250)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 250)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct EditSongMetadataView: View {
    let song: Song
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var artist: String
    @State private var key: String
    @State private var tags: String
    @State private var durationMinutes: Int
    @State private var durationSeconds: Int
    @State private var notes: String
    
    init(song: Song) {
        self.song = song
        self._title = State(initialValue: song.title ?? "")
        self._artist = State(initialValue: song.artist ?? "")
        self._key = State(initialValue: song.key ?? "")
        self._tags = State(initialValue: song.tagsArray.joined(separator: ", "))
        let totalSeconds = Int(song.durationSecs)
        self._durationMinutes = State(initialValue: totalSeconds / 60)
        self._durationSeconds = State(initialValue: totalSeconds % 60)
        self._notes = State(initialValue: song.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
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
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 60)
                        
                        Text(":")
                        
                        Picker("Seconds", selection: $durationSeconds) {
                            ForEach(0..<60) { second in
                                Text(String(format: "%02d", second))
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 60)
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        song.title = title.isEmpty ? nil : title
        song.artist = artist.isEmpty ? nil : artist
        song.key = key.isEmpty ? nil : key
        song.notes = notes.isEmpty ? nil : notes
        
        if !tags.isEmpty {
            let tagsArray = tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            song.tags = tagsArray as NSObject
        } else {
            song.tags = nil
        }
        
        let totalSeconds = (durationMinutes * 60) + durationSeconds
        song.durationSecs = Int32(totalSeconds)
        song.updatedAt = Date()
        
        dataStore.save()
        dismiss()
    }
}

struct SetlistPickerView: View {
    let song: Song
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSetlist: Setlist?
    @State private var selectedSet: Set?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataStore.setlists) { setlist in
                    Section(setlist.name ?? "Untitled") {
                        ForEach(setlist.setsArray.sorted { $0.position < $1.position }) { set in
                            Button {
                                addSongToSet(set)
                            } label: {
                                HStack {
                                    Text(set.name ?? "Set \(set.position + 1)")
                                    Spacer()
                                    Text("\(set.setItems?.count ?? 0) songs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Setlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addSongToSet(_ set: Set) {
        let setItem = SetItem(context: dataStore.viewContext)
        setItem.song = song
        setItem.set = set
        setItem.position = Int16(set.setItemsArray.count)
        
        dataStore.save()
        dismiss()
    }
}