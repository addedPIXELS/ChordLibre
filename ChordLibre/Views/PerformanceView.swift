//
//  PerformanceView.swift
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
import PDFKit

struct PerformanceView: View {
    let song: Song
    let inSetlistMode: Bool
    let onNextSong: (() -> Void)?
    let onPreviousSong: (() -> Void)?
    let onNextPage: (() -> Void)?
    let onPreviousPage: (() -> Void)?
    @Binding var externalShowControls: Bool
    @Binding var externalCurrentPage: Int
    @Binding var externalTotalPages: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: DataStore
    @State private var pdfView: PDFView?
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var zoomScale: CGFloat = 1.0
    @State private var autoScrollSpeed: Double = 0.0
    @State private var isAutoScrolling = false
    @State private var screenLocked = false
    @State private var showPageScrubber = false
    @State private var fitMode: PDFFitMode = .width
    
    init(song: Song, inSetlistMode: Bool = false, externalShowControls: Binding<Bool>? = nil, externalCurrentPage: Binding<Int>? = nil, externalTotalPages: Binding<Int>? = nil, onNextSong: (() -> Void)? = nil, onPreviousSong: (() -> Void)? = nil, onNextPage: (() -> Void)? = nil, onPreviousPage: (() -> Void)? = nil) {
        self.song = song
        self.inSetlistMode = inSetlistMode
        self.onNextSong = onNextSong
        self.onPreviousSong = onPreviousSong
        self.onNextPage = onNextPage
        self.onPreviousPage = onPreviousPage
        self._externalShowControls = externalShowControls ?? .constant(true)
        self._externalCurrentPage = externalCurrentPage ?? .constant(0)
        self._externalTotalPages = externalTotalPages ?? .constant(0)
    }
    
    enum PDFFitMode {
        case width, page
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            PDFViewerRepresentable(
                pdfData: song.pdfData ?? Data(),
                inSetlistMode: inSetlistMode,
                onNextSong: onNextSong,
                onPreviousSong: onPreviousSong,
                currentPage: $currentPage,
                totalPages: $totalPages,
                zoomScale: $zoomScale,
                fitMode: $fitMode,
                pdfView: $pdfView
            )
            .ignoresSafeArea()
            .onTapGesture {
                if !inSetlistMode {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                        if showControls {
                            resetControlsTimer()
                        }
                    }
                }
            }
            
            // Only show controls when NOT in setlist mode (setlist has its own controls)
            if !inSetlistMode && showControls {
                VStack {
                    topToolbar
                    Spacer()
                    if showPageScrubber {
                        pageScrubber
                    }
                    bottomToolbar
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            dataStore.updateSongLastOpened(song)
            UIApplication.shared.isIdleTimerDisabled = true
            if !inSetlistMode {
                resetControlsTimer()
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if inSetlistMode {
                externalCurrentPage = newPage
            }
        }
        .onChange(of: totalPages) { _, newTotal in
            if inSetlistMode {
                externalTotalPages = newTotal
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            controlsTimer?.invalidate()
        }
    }
    
    @ViewBuilder
    private var topToolbar: some View {
        HStack {
            if !inSetlistMode {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .padding()
            } else {
                // Page controls for setlist mode
                HStack(spacing: 12) {
                    Button {
                        previousPage()
                    } label: {
                        Image(systemName: "chevron.left.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(currentPage == 0)
                    .opacity(currentPage == 0 ? 0.5 : 1.0)
                    
                    Button {
                        nextPage()
                    } label: {
                        Image(systemName: "chevron.right.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(currentPage >= totalPages - 1)
                    .opacity(currentPage >= totalPages - 1 ? 0.5 : 1.0)
                }
                .padding(.leading)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(song.title ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.white)
                if let artist = song.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                if inSetlistMode {
                    // Essential controls for setlist mode
                    Button {
                        showPageScrubber.toggle()
                    } label: {
                        Image(systemName: "square.grid.3x3")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        toggleFitMode()
                    } label: {
                        Image(systemName: fitMode == .width ? "arrow.left.and.right" : "rectangle.portrait")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        screenLocked.toggle()
                    } label: {
                        Image(systemName: screenLocked ? "lock.fill" : "lock.open")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                
                Text(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("Page \(currentPage + 1) / \(totalPages)")
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
    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button {
                    previousPage()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .disabled(currentPage == 0)
                .opacity(currentPage == 0 ? 0.5 : 1.0)
                
                Button {
                    showPageScrubber.toggle()
                } label: {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button {
                    toggleFitMode()
                } label: {
                    Image(systemName: fitMode == .width ? "arrow.left.and.right" : "rectangle.portrait")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button {
                    isAutoScrolling.toggle()
                } label: {
                    Image(systemName: isAutoScrolling ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button {
                    screenLocked.toggle()
                } label: {
                    Image(systemName: screenLocked ? "lock.fill" : "lock.open")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button {
                    nextPage()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .disabled(currentPage >= totalPages - 1)
                .opacity(currentPage >= totalPages - 1 ? 0.5 : 1.0)
            }
            .padding()
            .background(Color.black.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private var pageScrubber: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { pageIndex in
                    Button {
                        currentPage = pageIndex
                        showPageScrubber = false
                    } label: {
                        VStack {
                            PageThumbnailView(
                                pdfData: song.pdfData ?? Data(),
                                pageIndex: pageIndex
                            )
                            .frame(width: 100, height: 140)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(currentPage == pageIndex ? Color.accentColor : Color.clear, lineWidth: 3)
                            )
                            
                            Text("\(pageIndex + 1)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: 180)
        .background(Color.black.opacity(0.9))
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
    
    private func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        } else if inSetlistMode, let onPreviousSong = onPreviousSong {
            // At first page, go to previous song
            onPreviousSong()
        }
    }
    
    private func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else if inSetlistMode, let onNextSong = onNextSong {
            // At last page, go to next song
            onNextSong()
        }
    }
    
    private func toggleFitMode() {
        fitMode = fitMode == .width ? .page : .width
        pdfView?.autoScales = fitMode == .page
        if fitMode == .width {
            pdfView?.scaleFactor = pdfView?.scaleFactorForSizeToFit ?? 1.0
        }
    }
}

struct PDFViewerRepresentable: UIViewRepresentable {
    let pdfData: Data
    let inSetlistMode: Bool
    let onNextSong: (() -> Void)?
    let onPreviousSong: (() -> Void)?
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomScale: CGFloat
    @Binding var fitMode: PerformanceView.PDFFitMode
    @Binding var pdfView: PDFView?
    
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = .black
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: nil)
        
        // Allow auto-scaling but disable manual zoom gestures
        view.autoScales = true
        
        // Disable pinch-to-zoom and other manual scale gestures
        DispatchQueue.main.async {
            for gesture in view.gestureRecognizers ?? [] {
                if gesture is UIPinchGestureRecognizer {
                    gesture.isEnabled = false
                }
            }
        }
        
        // Add custom swipe gesture for setlist navigation with higher priority
        if inSetlistMode {
            let swipeLeftGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeLeft(_:)))
            swipeLeftGesture.direction = .left
            swipeLeftGesture.numberOfTouchesRequired = 1
            swipeLeftGesture.delegate = context.coordinator
            
            let swipeRightGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeRight(_:)))
            swipeRightGesture.direction = .right  
            swipeRightGesture.numberOfTouchesRequired = 1
            swipeRightGesture.delegate = context.coordinator
            
            view.addGestureRecognizer(swipeLeftGesture)
            view.addGestureRecognizer(swipeRightGesture)
            
            // Disable PDFView's built-in page navigation gestures to prevent conflicts
            view.isUserInteractionEnabled = true
            for gesture in view.gestureRecognizers ?? [] {
                if gesture is UISwipeGestureRecognizer && gesture != swipeLeftGesture && gesture != swipeRightGesture {
                    gesture.isEnabled = false
                }
            }
        }
        
        if let document = PDFDocument(data: pdfData) {
            view.document = document
            
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
            }
            
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.pageChanged(_:)),
                name: .PDFViewPageChanged,
                object: view
            )
        }
        
        DispatchQueue.main.async {
            self.pdfView = view
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let page = uiView.document?.page(at: currentPage), uiView.currentPage != page {
            uiView.go(to: page)
        }
        
        // Ensure auto-scaling stays enabled 
        uiView.autoScales = true
        
        // Ensure totalPages is set correctly
        if let document = uiView.document, totalPages == 0 && document.pageCount > 0 {
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PDFViewerRepresentable
        
        init(_ parent: PDFViewerRepresentable) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPage) else { return }
            
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
        
        @objc func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
            // Swipe left = next page/song
            guard gesture.state == .ended else { return }
            
            DispatchQueue.main.async {
                if self.parent.currentPage < self.parent.totalPages - 1 {
                    self.parent.currentPage += 1
                } else if let onNextSong = self.parent.onNextSong {
                    onNextSong()
                }
            }
        }
        
        @objc func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
            // Swipe right = previous page/song
            guard gesture.state == .ended else { return }
            
            DispatchQueue.main.async {
                if self.parent.currentPage > 0 {
                    self.parent.currentPage -= 1
                } else if let onPreviousSong = self.parent.onPreviousSong {
                    onPreviousSong()
                }
            }
        }
        
        // UIGestureRecognizerDelegate methods
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow our custom swipe gestures to work alongside other gestures
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Our swipe gestures should not require other gestures to fail
            return false
        }
    }
}

struct PageThumbnailView: View {
    let pdfData: Data
    let pageIndex: Int
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(data: pdfData),
                  let page = document.page(at: pageIndex) else { return }
            
            // Use PDFPage's built-in thumbnail for correct orientation
            let thumbnailSize = CGSize(width: 100, height: 130)
            let thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
            DispatchQueue.main.async {
                self.thumbnail = thumbnail
            }
        }
    }
}