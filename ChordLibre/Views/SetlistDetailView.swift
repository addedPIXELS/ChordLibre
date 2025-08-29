//
//  SetlistDetailView.swift
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
import CoreData

struct SetlistDetailView: View {
    let setlist: Setlist
    @EnvironmentObject var dataStore: DataStore
    @State private var editMode: EditMode = .inactive
    @State private var isPerforming = false
    @State private var refreshTrigger = UUID()
    @State private var selectedSongIndex: Int?
    @State private var showingSetlistPerformance = false
    
    var body: some View {
        List {
            let sets = setlist.setsArray.sorted { $0.position < $1.position }
            ForEach(sets, id: \.objectID) { set in
                Section {
                    let items = set.setItemsArray.sorted { $0.position < $1.position }
                    ForEach(Array(items.enumerated()), id: \.element.objectID) { index, item in
                        if let song = item.song {
                            Button(action: {
                                // Calculate global index across all sets
                                var globalIndex = 0
                                for (setIndex, currentSet) in sets.enumerated() {
                                    let setItems = currentSet.setItemsArray.sorted { $0.position < $1.position }
                                    if setIndex < sets.firstIndex(of: set)! {
                                        globalIndex += setItems.count
                                    } else if setIndex == sets.firstIndex(of: set)! {
                                        globalIndex += index
                                        break
                                    }
                                }
                                selectedSongIndex = globalIndex
                                showingSetlistPerformance = true
                            }) {
                                SetItemRowView(song: song, setItem: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { indexSet in
                        deleteItems(from: set, at: indexSet)
                    }
                    .onMove { source, destination in
                        moveItems(in: set, from: source, to: destination)
                    }
                    
                    if editMode == .inactive {
                        NavigationLink(destination: SimpleSongPickerView(set: set).environmentObject(dataStore)) {
                            Label("Add Songs", systemImage: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                } header: {
                    SetHeaderView(set: set, setNumber: Int(set.position) + 1)
                }
            }
            
            Section {
                Button {
                    isPerforming = true
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("Perform Setlist")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .navigationTitle(setlist.name ?? "Untitled")
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, $editMode)
        .fullScreenCover(isPresented: $isPerforming) {
            SetlistPerformanceView(setlist: setlist)
        }
        .fullScreenCover(isPresented: $showingSetlistPerformance) {
            SetlistPerformanceView(setlist: setlist, startingSongIndex: selectedSongIndex)
                .environmentObject(dataStore)
        }
    }
    
    private func deleteItems(from set: Set, at offsets: IndexSet) {
        let items = set.setItemsArray.sorted { $0.position < $1.position }
        for index in offsets {
            dataStore.viewContext.delete(items[index])
        }
        dataStore.save()
    }
    
    private func moveItems(in set: Set, from source: IndexSet, to destination: Int) {
        let items = set.setItemsArray
        
        var sortedItems = items.sorted { $0.position < $1.position }
        sortedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in sortedItems.enumerated() {
            item.position = Int16(index)
        }
        
        dataStore.save()
    }
    
    private func formatDuration(_ seconds: Int32) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct SetHeaderView: View {
    let set: Set
    let setNumber: Int
    
    private var totalDuration: Int {
        let items = set.setItemsArray
        return items.reduce(0) { sum, item in
            sum + Int(item.song?.durationSecs ?? 0)
        }
    }
    
    var body: some View {
        HStack {
            Text(set.name ?? "Set \(setNumber)")
                .font(.headline)
            
            Spacer()
            
            if totalDuration > 0 {
                Text(formatDuration(Int32(totalDuration)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(set.setItems?.count ?? 0) songs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDuration(_ seconds: Int32) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct SetItemRowView: View {
    let song: Song
    let setItem: SetItem
    
    var body: some View {
        HStack {
            if let thumbnailData = song.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 50)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "Untitled")
                    .font(.body)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
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
        }
    }
    
    private func formatDuration(_ seconds: Int32) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct SimpleSongPickerView: View {
    let set: Set
    @EnvironmentObject var dataStore: DataStore
    @State private var songs: [Song] = []
    @State private var addedSongsCount = 0
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            if addedSongsCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Added \(addedSongsCount) song\(addedSongsCount == 1 ? "" : "s") to \(set.name ?? "set")")
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
            }
            
            List {
                if songs.isEmpty {
                    Text("All songs have been added to this set")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(songs, id: \.objectID) { song in
                        Button(action: {
                            addSongToSet(song)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(song.title ?? "Untitled")
                                        .foregroundColor(.primary)
                                    if let artist = song.artist {
                                        Text(artist)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Add Songs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if addedSongsCount > 0 {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadSongs()
        }
    }
    
    private func loadSongs() {
        let request = Song.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            let allSongs = try dataStore.viewContext.fetch(request)
            // Filter out songs already in this set
            let existingSongIDs = Swift.Set(set.setItemsArray.compactMap { $0.song?.objectID })
            songs = allSongs.filter { !existingSongIDs.contains($0.objectID) }
        } catch {
            print("Error loading songs: \(error)")
            songs = []
        }
    }
    
    private func addSongToSet(_ song: Song) {
        print("DEBUG: Adding song '\(song.title ?? "Unknown")' to set '\(set.name ?? "Unknown")'")
        
        // Create the new SetItem
        let setItem = SetItem(context: dataStore.viewContext)
        setItem.song = song
        setItem.set = set
        
        // Calculate the correct position (number of existing items)
        let currentItems = set.setItemsArray
        setItem.position = Int16(currentItems.count)
        
        print("DEBUG: Created SetItem with position \(setItem.position)")
        
        do {
            // Save the context
            try dataStore.viewContext.save()
            print("DEBUG: Successfully saved song to setlist")
            
            // Update the counter for UI feedback
            withAnimation {
                addedSongsCount += 1
            }
            
            // Remove from available songs list with animation
            withAnimation {
                songs.removeAll { $0.objectID == song.objectID }
            }
            
            print("DEBUG: Removed song from available list")
        } catch {
            print("DEBUG: Error saving song to set: \(error)")
            // If save fails, delete the setItem to clean up
            dataStore.viewContext.delete(setItem)
        }
    }
}

