//
//  MainView.swift
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

struct MainView: View {
    @StateObject private var dataStore = DataStore.shared
    @EnvironmentObject private var sharedFileManager: SharedFileManager
    @State private var selectedTab: NavigationTab = .all
    @State private var showingImport = false
    @State private var showingSharedImport = false
    @State private var editingChordsheet: ChordLibreSong?
    @State private var editingExistingSong: Song?
    @State private var selectedSong: Song?
    @State private var selectedSetlist: Setlist?
    @State private var isPerforming = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            contentView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingImport) {
            ImportView()
        }
        .sheet(isPresented: $showingSharedImport) {
            if !sharedFileManager.importedFiles.isEmpty {
                SharedImportView()
                    .environmentObject(sharedFileManager)
            }
        }
        .onChange(of: sharedFileManager.hasNewImports) { _, hasNew in
            if hasNew {
                showingSharedImport = true
            }
        }
        .fullScreenCover(isPresented: $isPerforming) {
            if let song = selectedSong {
                if song.isChordLibreSheet {
                    ChordLibreViewer(song: song)
                        .environmentObject(dataStore)
                } else {
                    PerformanceView(song: song)
                }
            } else if let setlist = selectedSetlist {
                SetlistPerformanceView(setlist: setlist)
            }
        }
        .fullScreenCover(item: $editingChordsheet) { chordsheet in
            ChordLibreEditor(song: chordsheet, existingSong: editingExistingSong)
                .environmentObject(dataStore)
        }
    }
    
    @ViewBuilder
    private var sidebar: some View {
        List {
            Section("Library") {
                ForEach(NavigationTab.libraryCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        selectedSetlist = nil
                        selectedSong = nil
                    } label: {
                        HStack {
                            Label(tab.title, systemImage: tab.icon)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedTab == tab ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                    .fontWeight(selectedTab == tab ? .medium : .regular)
                }
            }
            
            Section("Setlists") {
                Button {
                    selectedTab = .setlists
                    selectedSong = nil
                    selectedSetlist = nil
                } label: {
                    HStack {
                        Label("All Setlists", systemImage: "music.note.list")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == .setlists && selectedSetlist == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTab == .setlists && selectedSetlist == nil ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(selectedTab == .setlists && selectedSetlist == nil ? .accentColor : .primary)
                .fontWeight(selectedTab == .setlists && selectedSetlist == nil ? .medium : .regular)
                
                ForEach(dataStore.setlists) { setlist in
                    Button {
                        selectedTab = .setlist(setlist)
                        selectedSetlist = setlist
                        selectedSong = nil
                    } label: {
                        HStack {
                            Label(setlist.name ?? "Untitled", systemImage: "music.note")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSetlist?.objectID == setlist.objectID ? Color.accentColor.opacity(0.2) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedSetlist?.objectID == setlist.objectID ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(selectedSetlist?.objectID == setlist.objectID ? .accentColor : .primary)
                    .fontWeight(selectedSetlist?.objectID == setlist.objectID ? .medium : .regular)
                }
            }
            
            if isPerforming {
                Section {
                    Button {
                        selectedTab = .performing
                    } label: {
                        Label("Now Performing", systemImage: "play.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Section {
                Button {
                    selectedTab = .settings
                } label: {
                    HStack {
                        Label("Settings", systemImage: "gear")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == .settings ? Color.accentColor.opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTab == .settings ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(selectedTab == .settings ? .accentColor : .primary)
                .fontWeight(selectedTab == .settings ? .medium : .regular)
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("ChordLibre")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import PDF", systemImage: "doc.badge.plus")
                    }

                    Button {
                        createNewChordsheet()
                    } label: {
                        Label("New Chordsheet", systemImage: "music.note.list")
                    }

                    Button {
                        createNewSetlist()
                    } label: {
                        Label("New Setlist", systemImage: "plus.rectangle.on.folder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .id("main-add-menu")
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Show detail views if items are selected, otherwise show main content
            if let song = selectedSong {
                SongDetailView(
                    song: song,
                    onPerform: {
                        selectedSong = song
                        isPerforming = true
                    },
                    onDismiss: {
                        selectedSong = nil
                    }
                )
                .environmentObject(dataStore)
            } else if let setlist = selectedSetlist {
                SetlistDetailView(setlist: setlist)
                    .environmentObject(dataStore)
            } else {
                // Main content based on selected tab
                switch selectedTab {
                case .all, .byTitle, .byArtist, .recent:
                    LibraryView(filter: selectedTab, selectedSong: $selectedSong)
                        .environmentObject(dataStore)
                case .setlists:
                    SetlistsListView(selectedSetlist: $selectedSetlist)
                        .environmentObject(dataStore)
                case .setlist(let setlist):
                    SetlistSongsView(setlist: setlist, selectedSong: $selectedSong)
                        .environmentObject(dataStore)
                case .performing:
                    PerformingStatusView()
                case .settings:
                    SettingsView()
                }
            }
            
            // Ad banner at bottom - unintrusive
            AdBannerContainer()
        }
    }
    
    
    private func createNewSetlist() {
        let setlist = dataStore.createSetlist(name: "New Setlist")
        selectedTab = .setlist(setlist)
        selectedSetlist = setlist
    }

    private func createNewChordsheet() {
        // Create a blank chordsheet with one empty section
        let blankChordsheet = ChordLibreSong(
            title: "Untitled",
            artist: nil,
            key: .C,
            sections: [
                ChordLibreSection(label: "Verse 1", lines: [
                    ChordLibreLine(lyrics: "", chord: nil)
                ])
            ]
        )

        // Open in full-screen editor
        editingExistingSong = nil // This is a new song
        editingChordsheet = blankChordsheet
    }
}

enum NavigationTab: Hashable {
    case all
    case byTitle
    case byArtist
    case recent
    case setlists
    case setlist(Setlist)
    case performing
    case settings
    
    static let libraryCases: [NavigationTab] = [.all, .byTitle, .byArtist, .recent]
    
    var title: String {
        switch self {
        case .all: return "All Songs"
        case .byTitle: return "By Title"
        case .byArtist: return "By Artist"
        case .recent: return "Recent"
        case .setlists: return "Setlists"
        case .setlist(let setlist): return setlist.name ?? "Untitled"
        case .performing: return "Now Performing"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "music.note"
        case .byTitle: return "textformat"
        case .byArtist: return "person.2"
        case .recent: return "clock"
        case .setlists: return "music.note.list"
        case .setlist: return "music.note"
        case .performing: return "play.circle.fill"
        case .settings: return "gear"
        }
    }
}