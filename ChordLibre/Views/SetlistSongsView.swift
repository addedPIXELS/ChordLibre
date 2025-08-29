//
//  SetlistSongsView.swift
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

struct SetlistSongsView: View {
    let setlist: Setlist
    @Binding var selectedSong: Song?
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        List {
            let sets = setlist.setsArray.sorted { $0.position < $1.position }
            ForEach(sets) { set in
                Section {
                    let items = set.setItemsArray.sorted { $0.position < $1.position }
                    ForEach(items) { item in
                        if let song = item.song {
                            Button(action: {
                                selectedSong = song
                            }) {
                                SetItemRowView(song: song, setItem: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } header: {
                    SetHeaderView(set: set, setNumber: Int(set.position) + 1)
                }
            }
        }
        .navigationTitle(setlist.name ?? "Untitled")
        .navigationBarTitleDisplayMode(.large)
    }
}