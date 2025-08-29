//
//  SetlistsListView.swift
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

struct SetlistsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedSetlist: Setlist?
    @State private var showingCreateSheet = false
    @State private var searchText = ""
    
    var filteredSetlists: [Setlist] {
        if searchText.isEmpty {
            return dataStore.setlists
        } else {
            return dataStore.setlists.filter { setlist in
                (setlist.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (setlist.venue?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredSetlists) { setlist in
                SetlistRowView(setlist: setlist)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSetlist = setlist
                    }
                    .contextMenu {
                        Button {
                            duplicateSetlist(setlist)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            performSetlist(setlist)
                        } label: {
                            Label("Perform", systemImage: "play.circle")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            dataStore.deleteSetlist(setlist)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                deleteSetlists(at: indexSet)
            }
        }
        .searchable(text: $searchText, prompt: "Search setlists")
        .navigationTitle("Setlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateSetlistView()
        }
    }
    
    private func deleteSetlists(at offsets: IndexSet) {
        for index in offsets {
            let setlist = filteredSetlists[index]
            dataStore.deleteSetlist(setlist)
        }
    }
    
    private func duplicateSetlist(_ setlist: Setlist) {
        let newSetlist = dataStore.createSetlist(
            name: "\(setlist.name ?? "Untitled") (Copy)",
            venue: setlist.venue,
            eventDate: nil,
            notes: setlist.notes
        )
        
        let sets = setlist.setsArray
        for originalSet in sets {
            let newSet = dataStore.createSet(in: newSetlist, name: originalSet.name ?? "Set")
            
            let setItems = originalSet.setItemsArray
            for item in setItems {
                if let song = item.song {
                    dataStore.addSongToSet(song, set: newSet)
                }
            }
        }
    }
    
    private func performSetlist(_ setlist: Setlist) {
        selectedSetlist = setlist
    }
}

struct SetlistRowView: View {
    let setlist: Setlist
    
    private var songCount: Int {
        let sets = setlist.setsArray
        return sets.reduce(0) { count, set in
            count + set.setItemsArray.count
        }
    }
    
    private var totalDuration: Int {
        let sets = setlist.setsArray
        var duration = 0
        for set in sets {
            let items = set.setItemsArray
            for item in items {
                duration += Int(item.song?.durationSecs ?? 0)
            }
        }
        return duration
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(setlist.name ?? "Untitled")
                    .font(.headline)
                
                Spacer()
                
                if let eventDate = setlist.eventDate {
                    Text(eventDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let venue = setlist.venue {
                Text(venue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(setlist.sets?.count ?? 0) sets", systemImage: "music.note.list")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(songCount) songs", systemImage: "music.note")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if totalDuration > 0 {
                    Label(formatDuration(totalDuration), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct CreateSetlistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: DataStore
    
    @State private var name = ""
    @State private var venue = ""
    @State private var eventDate = Date()
    @State private var hasEventDate = false
    @State private var notes = ""
    @State private var numberOfSets = 1
    
    var body: some View {
        NavigationView {
            Form {
                Section("Setlist Information") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Venue (optional)", text: $venue)
                        .textInputAutocapitalization(.words)
                    
                    Toggle("Event Date", isOn: $hasEventDate)
                    
                    if hasEventDate {
                        DatePicker("Date", selection: $eventDate, displayedComponents: [.date])
                    }
                }
                
                Section("Sets") {
                    Stepper("Number of Sets: \(numberOfSets)", value: $numberOfSets, in: 1...10)
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Setlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSetlist()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createSetlist() {
        let setlist = dataStore.createSetlist(
            name: name,
            venue: venue.isEmpty ? nil : venue,
            eventDate: hasEventDate ? eventDate : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        for i in 1...numberOfSets {
            _ = dataStore.createSet(in: setlist, name: "Set \(i)")
        }
        
        dismiss()
    }
}