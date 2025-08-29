//
//  SongDetailView.swift
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

struct SongDetailView: View {
    let song: Song
    let onPerform: () -> Void
    let onDismiss: (() -> Void)?
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init(song: Song, onPerform: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.song = song
        self.onPerform = onPerform
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let thumbnailData = song.thumbnailData,
                       let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 400)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(song.title ?? "Untitled")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let artist = song.artist {
                            Text(artist)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            if let key = song.key {
                                Label(key, systemImage: "music.note")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            if song.durationSecs > 0 {
                                let duration = song.durationSecs
                                Label(formatDuration(duration), systemImage: "clock")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        
                        if !song.tagsArray.isEmpty {
                            let tags = song.tagsArray
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        
                        if let notes = song.notes {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top)
                        }
                        
                        HStack {
                            Text("Created")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(song.createdAt ?? Date(), style: .date)
                                .font(.caption)
                            
                            if let lastOpened = song.lastOpenedAt {
                                Spacer()
                                Text("Last opened")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(lastOpened, style: .relative)
                                    .font(.caption)
                            }
                        }
                        .padding(.top)
                    }
                    .padding()
                }
                .padding(.bottom, 20)
            }
            
            Button {
                onPerform()
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Perform")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Song Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if horizontalSizeClass == .regular, let onDismiss = onDismiss {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(.accentColor)
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Int32) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}