//
//  DataStore.swift
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

import Foundation
import CoreData
import Combine

@MainActor
class DataStore: ObservableObject {
    static let shared = DataStore()
    
    private let persistenceController = PersistenceController.shared
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    @Published var songs: [Song] = []
    @Published var setlists: [Setlist] = []
    @Published var searchText = ""
    @Published var sortOption: SortOption = .title
    @Published var filterOption: FilterOption = .all
    
    private var cancellables = Swift.Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadData()
    }
    
    private func setupBindings() {
        Publishers.CombineLatest3($searchText, $sortOption, $filterOption)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadSongs()
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        loadSongs()
        loadSetlists()
    }
    
    func loadSongs() {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        
        if !searchText.isEmpty {
            let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            let artistPredicate = NSPredicate(format: "artist CONTAINS[cd] %@", searchText)
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, artistPredicate])
        }
        
        switch sortOption {
        case .title:
            request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        case .artist:
            request.sortDescriptors = [
                NSSortDescriptor(key: "artist", ascending: true),
                NSSortDescriptor(key: "title", ascending: true)
            ]
        case .recent:
            request.sortDescriptors = [NSSortDescriptor(key: "lastOpenedAt", ascending: false)]
        case .created:
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        }
        
        do {
            songs = try viewContext.fetch(request)
        } catch {
            print("Error fetching songs: \(error)")
            songs = []
        }
    }
    
    func loadSetlists() {
        let request: NSFetchRequest<Setlist> = Setlist.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            setlists = try viewContext.fetch(request)
        } catch {
            print("Error fetching setlists: \(error)")
            setlists = []
        }
    }
    
    func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    func deleteSong(_ song: Song) {
        viewContext.delete(song)
        save()
        loadSongs()
    }
    
    func deleteSetlist(_ setlist: Setlist) {
        viewContext.delete(setlist)
        save()
        loadSetlists()
    }
    
    func createSetlist(name: String, venue: String? = nil, eventDate: Date? = nil, notes: String? = nil) -> Setlist {
        let setlist = Setlist(context: viewContext)
        setlist.id = UUID()
        setlist.name = name
        setlist.venue = venue
        setlist.eventDate = eventDate
        setlist.notes = notes
        
        save()
        loadSetlists()
        
        return setlist
    }
    
    func createSet(in setlist: Setlist, name: String) -> Set {
        let set = Set(context: viewContext)
        set.id = UUID()
        set.name = name
        set.position = Int16(setlist.sets?.count ?? 0)
        set.setlist = setlist
        
        save()
        
        return set
    }
    
    func addSongToSet(_ song: Song, set: Set) {
        print("DEBUG DataStore: addSongToSet called for song '\(song.title ?? "Unknown")' in set '\(set.name ?? "Unknown")'")
        let setItem = SetItem(context: viewContext)
        setItem.position = Int16(set.setItems?.count ?? 0)
        setItem.song = song
        setItem.set = set
        
        print("DEBUG DataStore: Created SetItem at position \(setItem.position)")
        save()
        print("DEBUG DataStore: Save completed")
        
        // Force refresh of the setlists data
        loadSetlists()
        print("DEBUG DataStore: Setlists reloaded")
    }
    
    func updateSongLastOpened(_ song: Song) {
        song.lastOpenedAt = Date()
        save()
    }
    
    func getAllSongs() -> [Song] {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching all songs: \(error)")
            return []
        }
    }
    
    enum SortOption: String, CaseIterable {
        case title = "Title"
        case artist = "Artist"
        case recent = "Recent"
        case created = "Created"
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case byTitle = "By Title"
        case byArtist = "By Artist"
        case recent = "Recent"
    }
}