// Copyright (c) 2020-2021 InSeven Limited
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Combine
import SwiftUI

import BookmarksCore
import Interact

struct Sidebar: View {

    @Environment(\.manager) var manager: BookmarksManager
    @ObservedObject var tagsView: TagsView
    @ObservedObject var settings: BookmarksCore.Settings

    static let allBookmarks = "uk.co.inseven.bookmarks.all-bookmarks"
    static let untagged = "uk.co.inseven.bookmarks.untagged"
    static let favorites = "uk.co.inseven.bookmarks.favorites"
    static let tag = "uk.co.inseven.bookmarks.tag"

    @State var selection: String? = allBookmarks

    var body: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(destination: ContentView(databaseView: DatabaseView(database: manager.database)).navigationTitle("All Bookmarks")) {
                    Label("All Bookmarks", systemImage: "bookmark")
                }
                .tag(Self.allBookmarks)
                NavigationLink(destination: ContentView(databaseView: DatabaseView(database: manager.database, tags: [])).navigationTitle("Untagged")) {
                    Label("Untagged", systemImage: "tag")
                }
                .tag(Self.untagged)
            }
            Section(header: Text("Favourites")) {
                ForEach(settings.favoriteTags) { tag in
                    NavigationLink(destination: ContentView(databaseView: DatabaseView(database: manager.database, tags: [tag])).navigationTitle(tag)) {
                        Label(tag, systemImage: "tag")
                    }
                    .contextMenu(ContextMenu(menuItems: {
                        Button("Remove from Favourites") {
                            settings.favoriteTags = settings.favoriteTags.filter { $0 != tag }
                        }
                        Divider()
                        Button("View on Pinboard") {
                            do {
                                guard let user = manager.user else {
                                    return
                                }
                                NSWorkspace.shared.open(try tag.pinboardUrl(for: user))
                            } catch {
                                print("Failed to open on Pinboard error \(error)")
                            }
                        }
                    }))
                    .tag(Self.favorites + "." + tag)
                }
            }
            Section(header: Text("Tags")) {
                ForEach(tagsView.tags) { tag in
                    NavigationLink(destination: ContentView(databaseView: DatabaseView(database: manager.database, tags: [tag])).navigationTitle(tag)) {
                        HStack {
                            Image(systemName: "tag")
                                .renderingMode(.template)
                                .foregroundColor(.secondary)
                            Text(tag)
                        }
                    }
                    .contextMenu(ContextMenu(menuItems: {
                        Button("Add to Favourites") {
                            var favoriteTags = settings.favoriteTags
                            favoriteTags.append(tag)
                            settings.favoriteTags = favoriteTags
                        }
                        Divider()
                        Button("View on Pinboard") {
                            do {
                                guard let user = manager.user else {
                                    return
                                }
                                NSWorkspace.shared.open(try tag.pinboardUrl(for: user))
                            } catch {
                                print("Failed to open on Pinboard error \(error)")
                            }
                        }
                    }))
                    .tag(Self.tag + "." + tag)
                }
            }
        }
        .onAppear {
            tagsView.start()
        }
        .onDisappear {
            tagsView.stop()
        }
        .onChange(of: selection, perform: { selection in
            guard let selection = selection else {
                return
            }
            print(selection)
        })
    }
}
