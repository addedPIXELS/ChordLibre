//
//  Persistence.swift
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

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        let sampleSong1 = Song(context: viewContext)
        sampleSong1.id = UUID()
        sampleSong1.title = "Wonderwall"
        sampleSong1.artist = "Oasis"
        sampleSong1.key = "G"
        sampleSong1.tags = ["Rock", "90s"] as NSObject
        sampleSong1.createdAt = Date()
        sampleSong1.updatedAt = Date()
        sampleSong1.pdfHash = "sample_hash_1"
        sampleSong1.pdfData = Data()
        
        let sampleSong2 = Song(context: viewContext)
        sampleSong2.id = UUID()
        sampleSong2.title = "Hotel California"
        sampleSong2.artist = "Eagles"
        sampleSong2.key = "Bm"
        sampleSong2.tags = ["Classic Rock", "70s"] as NSObject
        sampleSong2.createdAt = Date()
        sampleSong2.updatedAt = Date()
        sampleSong2.pdfHash = "sample_hash_2"
        sampleSong2.pdfData = Data()
        
        let sampleSetlist = Setlist(context: viewContext)
        sampleSetlist.id = UUID()
        sampleSetlist.name = "Saturday Night Gig"
        sampleSetlist.venue = "The Blue Note"
        sampleSetlist.eventDate = Date()
        
        let sampleSet = Set(context: viewContext)
        sampleSet.id = UUID()
        sampleSet.name = "Set 1"
        sampleSet.position = 0
        sampleSet.setlist = sampleSetlist
        
        let setItem1 = SetItem(context: viewContext)
        setItem1.position = 0
        setItem1.song = sampleSong1
        setItem1.set = sampleSet
        
        let setItem2 = SetItem(context: viewContext)
        setItem2.position = 1
        setItem2.song = sampleSong2
        setItem2.set = sampleSet
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ChordLibre")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
