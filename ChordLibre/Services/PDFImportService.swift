//
//  PDFImportService.swift
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
import PDFKit
import CryptoKit
import CoreData
import UIKit

class PDFImportService {
    static let shared = PDFImportService()
    
    private init() {}
    
    func importPDF(from url: URL, context: NSManagedObjectContext) async throws -> Song {
        let pdfData = try Data(contentsOf: url)
        return try await importPDF(data: pdfData, context: context)
    }
    
    func importPDF(data pdfData: Data, context: NSManagedObjectContext) async throws -> Song {
        let pdfHash = computeHash(for: pdfData)
        
        if let existingSong = try await checkForDuplicate(hash: pdfHash, in: context) {
            throw ImportError.duplicateFound(existingSong)
        }
        
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw ImportError.invalidPDF
        }
        
        let song = Song(context: context)
        song.id = UUID()
        song.pdfData = pdfData
        song.pdfHash = pdfHash
        song.createdAt = Date()
        song.updatedAt = Date()
        
        if let thumbnailData = generateThumbnail(from: pdfDocument) {
            song.thumbnailData = thumbnailData
        }
        
        return song
    }
    
    private func computeHash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func checkForDuplicate(hash: String, in context: NSManagedObjectContext) async throws -> Song? {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.predicate = NSPredicate(format: "pdfHash == %@", hash)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func generateThumbnail(from document: PDFDocument, pageIndex: Int = 0) -> Data? {
        guard let page = document.page(at: pageIndex) else { return nil }
        
        // Use PDFPage's built-in thumbnail generation for correct orientation
        let thumbnailSize = CGSize(width: 200, height: 260) // Standard aspect ratio
        let thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            return thumbnailData
        }
        
        // Fallback to manual generation if thumbnail fails
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0 && pageRect.height > 0 else { return nil }
        
        let aspectRatio = pageRect.height / pageRect.width
        let finalSize = CGSize(width: 200, height: 200 * aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: finalSize))
            
            // Scale to fit and draw with proper orientation
            let pageRect = page.bounds(for: .mediaBox)
            let scaleX = finalSize.width / pageRect.width
            let scaleY = finalSize.height / pageRect.height
            
            context.cgContext.scaleBy(x: scaleX, y: scaleY)
            context.cgContext.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    func generatePageThumbnails(for document: PDFDocument) async -> [Data] {
        var thumbnails: [Data] = []
        
        for i in 0..<min(document.pageCount, 20) {
            if let thumbnailData = generateThumbnail(from: document, pageIndex: i) {
                thumbnails.append(thumbnailData)
            }
        }
        
        return thumbnails
    }
    
    enum ImportError: LocalizedError {
        case invalidPDF
        case duplicateFound(Song)
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "The file is not a valid PDF document."
            case .duplicateFound:
                return "This PDF has already been imported."
            case .saveFailed:
                return "Failed to save the imported PDF."
            }
        }
    }
}