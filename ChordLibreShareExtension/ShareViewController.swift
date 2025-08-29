//
//  ShareViewController.swift
//  ChordLibreShareExtension
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

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (item, error) in
                if let error = error {
                    print("Error loading PDF: \(error)")
                    DispatchQueue.main.async {
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                    return
                }
                
                var pdfData: Data?
                
                if let url = item as? URL {
                    do {
                        pdfData = try Data(contentsOf: url)
                    } catch {
                        print("Error reading PDF from URL: \(error)")
                    }
                } else if let data = item as? Data {
                    pdfData = data
                }
                
                guard let data = pdfData else {
                    DispatchQueue.main.async {
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                    return
                }
                
                self?.savePDFToSharedContainer(data: data)
            }
        } else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func savePDFToSharedContainer(data: Data) {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.chordlibre.app") else {
            print("Unable to access shared container")
            DispatchQueue.main.async {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
            return
        }
        
        let incomingFolder = sharedContainer.appendingPathComponent("Incoming")
        
        do {
            try FileManager.default.createDirectory(at: incomingFolder, withIntermediateDirectories: true, attributes: nil)
            
            let fileName = "imported_pdf_\(Date().timeIntervalSince1970).pdf"
            let fileURL = incomingFolder.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            
            DispatchQueue.main.async {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: { _ in
                    self.openMainApp()
                })
            }
        } catch {
            print("Error saving PDF: \(error)")
            DispatchQueue.main.async {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
    
    private func openMainApp() {
        guard let url = URL(string: "chordlibre://import") else { return }
        
        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))
        
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
    }
    
    @objc private func openURL(_ url: URL) {
        // This method is called via the responder chain
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
}