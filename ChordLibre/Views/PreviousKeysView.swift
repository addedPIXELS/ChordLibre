//
//  PreviousKeysView.swift
//  ChordLibre
//
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

struct PreviousKeysView: View {
    let song: Song
    let onSelectKey: (MusicalKey) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if song.previousKeys.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No previous keys recorded")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Transpose and perform this song to build history")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(song.previousKeys.reversed(), id: \.performedAt) { entry in
                        Button {
                            onSelectKey(entry.key)
                            dismiss()
                        } label: {
                            HStack {
                                // Key badge
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Text(entry.key.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Key of \(entry.key.displayName)")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(entry.performedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Previous Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PreviousKeysView(song: Song()) { _ in }
}
