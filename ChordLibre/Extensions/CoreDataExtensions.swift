//
//  CoreDataExtensions.swift
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
import Foundation

// MARK: - Core Data Extensions

// MARK: - Convenience methods

extension Song {
    var tagsArray: [String] {
        return (tags as? [String]) ?? []
    }
}

extension Setlist {
    var setsArray: [Set] {
        return (sets?.array as? [Set]) ?? []
    }
}

extension Set {
    var setItemsArray: [SetItem] {
        return (setItems?.array as? [SetItem]) ?? []
    }
}