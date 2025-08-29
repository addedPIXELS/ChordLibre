//
//  SetlistPerformanceView.swift
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

struct SetlistPerformanceView: View {
    let setlist: Setlist
    private let startingSongIndex: Int?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: DataStore
    @State private var currentSetIndex = 0
    @State private var currentSongIndex = 0
    @State private var showControls = true
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var currentPage = 0
    @State private var totalPages = 0
    
    init(setlist: Setlist, startingSongIndex: Int? = nil) {
        self.setlist = setlist
        self.startingSongIndex = startingSongIndex
    }
    
    private var sets: [Set] {
        setlist.setsArray.sorted { $0.position < $1.position }
    }
    
    private var currentSet: Set? {
        guard currentSetIndex < sets.count else { return nil }
        return sets[currentSetIndex]
    }
    
    private var currentSetItems: [SetItem] {
        guard let set = currentSet else { return [] }
        let items = set.setItemsArray
        return items.sorted { $0.position < $1.position }
    }
    
    private var currentSong: Song? {
        guard currentSongIndex < currentSetItems.count else { return nil }
        return currentSetItems[currentSongIndex].song
    }
    
    private var totalSongs: Int {
        sets.reduce(0) { count, set in
            count + (set.setItems?.count ?? 0)
        }
    }
    
    private var completedSongs: Int {
        var count = 0
        for i in 0..<currentSetIndex {
            count += sets[i].setItemsArray.count
        }
        count += currentSongIndex
        return count
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let song = currentSong {
                PerformanceView(
                    song: song, 
                    inSetlistMode: true,
                    externalShowControls: $showControls,
                    externalCurrentPage: $currentPage,
                    externalTotalPages: $totalPages,
                    onNextSong: canGoNext() ? { nextSong() } : nil,
                    onPreviousSong: canGoPrevious() ? { previousSong() } : nil,
                    onNextPage: nil,
                    onPreviousPage: nil
                )
                .environmentObject(dataStore)
                .id("\(currentSetIndex)-\(currentSongIndex)-\(song.objectID)")
            }
            
            if showControls {
                VStack(spacing: 0) {
                    // Top bar with dismiss and info
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .padding()
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text(setlist.name ?? "Untitled")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("\(currentSet?.name ?? "") • Song \(currentSongIndex + 1)/\(currentSetItems.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatTime(elapsedTime))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Text("\(completedSongs + 1)/\(totalSongs)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                    }
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.black.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Bottom control buttons
                    VStack(spacing: 0) {
                        HStack(spacing: 20) {
                            Button {
                                previousSong()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.largeTitle)
                                    if let prevSong = previousSongInfo() {
                                        Text(prevSong.title ?? "")
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                }
                                .foregroundColor(.white)
                            }
                            .disabled(!canGoPrevious())
                            .opacity(canGoPrevious() ? 1.0 : 0.5)
                            
                            Spacer()
                            
                            // Center info with page controls
                            VStack(spacing: 8) {
                                Text(currentSong?.title ?? "No Song")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let artist = currentSong?.artist {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                // Page info and controls
                                HStack(spacing: 12) {
                                    Button {
                                        handlePreviousPage()
                                    } label: {
                                        Image(systemName: "chevron.left.circle")
                                            .font(.title3)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .disabled(currentPage == 0 && !canGoPrevious())
                                    .opacity((currentPage == 0 && !canGoPrevious()) ? 0.3 : 0.8)
                                    
                                    Text("Page \(currentPage + 1) / \(totalPages)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Button {
                                        handleNextPage()
                                    } label: {
                                        Image(systemName: "chevron.right.circle")
                                            .font(.title3)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .disabled(currentPage >= totalPages - 1 && !canGoNext())
                                    .opacity((currentPage >= totalPages - 1 && !canGoNext()) ? 0.3 : 0.8)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                nextSong()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.largeTitle)
                                    if let nextSong = nextSongInfo() {
                                        Text(nextSong.title ?? "")
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                }
                                .foregroundColor(.white)
                            }
                            .disabled(!canGoNext())
                            .opacity(canGoNext() ? 1.0 : 0.5)
                        }
                        .padding()
                        
                        progressBar
                    }
                    .background(Color.black.opacity(0.8))
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Only handle horizontal swipes
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width > 50 && canGoPrevious() {
                            // Swipe right for previous song
                            withAnimation {
                                previousSong()
                            }
                        } else if value.translation.width < -50 && canGoNext() {
                            // Swipe left for next song
                            withAnimation {
                                nextSong()
                            }
                        }
                    }
                }
        )
        .onAppear {
            initializeStartingPosition()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    @ViewBuilder
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding()
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(setlist.name ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(currentSet?.name ?? "") • Song \(currentSongIndex + 1)/\(currentSetItems.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(elapsedTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("\(completedSongs + 1)/\(totalSongs)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    previousSong()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.largeTitle)
                        if let prevSong = previousSongInfo() {
                            Text(prevSong.title ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.white)
                }
                .disabled(!canGoPrevious())
                .opacity(canGoPrevious() ? 1.0 : 0.5)
                
                Spacer()
                
                VStack {
                    Text(currentSong?.title ?? "No Song")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let artist = currentSong?.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Button {
                    nextSong()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.largeTitle)
                        if let nextSong = nextSongInfo() {
                            Text(nextSong.title ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.white)
                }
                .disabled(!canGoNext())
                .opacity(canGoNext() ? 1.0 : 0.5)
            }
            .padding()
            
            progressBar
        }
        .background(Color.black.opacity(0.8))
    }
    
    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat(completedSongs + 1) / CGFloat(max(totalSongs, 1)))
            }
        }
        .frame(height: 4)
    }
    
    private func canGoPrevious() -> Bool {
        currentSongIndex > 0 || currentSetIndex > 0
    }
    
    private func canGoNext() -> Bool {
        currentSongIndex < currentSetItems.count - 1 || currentSetIndex < sets.count - 1
    }
    
    private func previousSong() {
        if currentSongIndex > 0 {
            currentSongIndex -= 1
        } else if currentSetIndex > 0 {
            currentSetIndex -= 1
            let prevSet = sets[currentSetIndex]
            currentSongIndex = max(0, prevSet.setItemsArray.count - 1)
        }
        currentPage = 0  // Reset to first page of new song
    }
    
    private func nextSong() {
        if currentSongIndex < currentSetItems.count - 1 {
            currentSongIndex += 1
        } else if currentSetIndex < sets.count - 1 {
            currentSetIndex += 1
            currentSongIndex = 0
        }
        currentPage = 0  // Reset to first page of new song
    }
    
    private func previousSongInfo() -> Song? {
        if currentSongIndex > 0 {
            return currentSetItems[currentSongIndex - 1].song
        } else if currentSetIndex > 0 {
            let prevSet = sets[currentSetIndex - 1]
            let items = prevSet.setItemsArray
            if !items.isEmpty {
                return items.sorted { $0.position < $1.position }.last?.song
            }
        }
        return nil
    }
    
    private func nextSongInfo() -> Song? {
        if currentSongIndex < currentSetItems.count - 1 {
            return currentSetItems[currentSongIndex + 1].song
        } else if currentSetIndex < sets.count - 1 {
            let nextSet = sets[currentSetIndex + 1]
            let items = nextSet.setItemsArray
            if !items.isEmpty {
                return items.sorted { $0.position < $1.position }.first?.song
            }
        }
        return nil
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    @ViewBuilder
    private var hybridTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding()
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(setlist.name ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(currentSet?.name ?? "") • Song \(currentSongIndex + 1)/\(currentSetItems.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(elapsedTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("\(completedSongs + 1)/\(totalSongs)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private var hybridBottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // Song navigation
                Button {
                    previousSong()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.largeTitle)
                        if let prevSong = previousSongInfo() {
                            Text(prevSong.title ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.white)
                }
                .disabled(!canGoPrevious())
                .opacity(canGoPrevious() ? 1.0 : 0.5)
                
                Spacer()
                
                // Center info with page controls
                VStack(spacing: 8) {
                    Text(currentSong?.title ?? "No Song")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let artist = currentSong?.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Page info and controls
                    HStack(spacing: 12) {
                        Button {
                            handlePreviousPage()
                        } label: {
                            Image(systemName: "chevron.left.circle")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .disabled(currentPage == 0 && !canGoPrevious())
                        .opacity((currentPage == 0 && !canGoPrevious()) ? 0.3 : 0.8)
                        
                        Text("Page \(currentPage + 1) / \(totalPages)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button {
                            handleNextPage()
                        } label: {
                            Image(systemName: "chevron.right.circle")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .disabled(currentPage >= totalPages - 1 && !canGoNext())
                        .opacity((currentPage >= totalPages - 1 && !canGoNext()) ? 0.3 : 0.8)
                    }
                }
                
                Spacer()
                
                Button {
                    nextSong()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.largeTitle)
                        if let nextSong = nextSongInfo() {
                            Text(nextSong.title ?? "")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.white)
                }
                .disabled(!canGoNext())
                .opacity(canGoNext() ? 1.0 : 0.5)
            }
            .padding()
            
            progressBar
        }
        .background(Color.black.opacity(0.8))
    }
    
    private func handleNextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else if canGoNext() {
            // At last page, go to next song and reset to first page
            nextSong()
            currentPage = 0
        }
    }
    
    private func handlePreviousPage() {
        if currentPage > 0 {
            currentPage -= 1
        } else if canGoPrevious() {
            // At first page, go to previous song and set to last page
            previousSong()
            // Note: We'll need to set currentPage to the last page of the new song
            // This will be handled by the PerformanceView's onChange
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                currentPage = max(0, totalPages - 1)
            }
        }
    }
    
    private func initializeStartingPosition() {
        guard let startingSongIndex = startingSongIndex else { return }
        
        var globalIndex = 0
        for (setIndex, set) in sets.enumerated() {
            let setItems = set.setItemsArray.sorted { $0.position < $1.position }
            
            if globalIndex + setItems.count > startingSongIndex {
                // Found the right set
                currentSetIndex = setIndex
                currentSongIndex = startingSongIndex - globalIndex
                return
            }
            
            globalIndex += setItems.count
        }
    }
}