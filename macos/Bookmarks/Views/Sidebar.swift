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

enum Tags {
    case allBookmarks
    case untagged
    case favorites(tag: String)
    case tag(tag: String)
}


struct FocusedMessageKey : FocusedValueKey {
        typealias Value = Binding<Tags?>
}


extension FocusedValues {
    var sidebarSelection: FocusedMessageKey.Value? {
        get { self[FocusedMessageKey.self] }
        set { self[FocusedMessageKey.self] = newValue }
    }
}

// TODO: Rename this.
extension Tags: CustomStringConvertible, Hashable, Identifiable {

    var id: String { String(describing: self) }

    var description: String {
        switch self {
        case .allBookmarks:
            return "uk.co.inseven.bookmarks.all-bookmarks"
        case .untagged:
            return "uk.co.inseven.bookmarks.untagged"
        case .favorites(let tag):
            return "uk.co.inseven.bookmarks.favorites.\(tag)"
        case .tag(let tag):
            return "uk.co.inseven.bookmarks.tag.\(tag)"
        }
    }

}


extension String {

    var favoriteId: Tags { Tags.favorites(tag: self) }
    var tagId: Tags { Tags.tag(tag: self) }

}

// TODO: Wrap the navigation link in something more elegant?


struct SidebarLink: View {

    @Environment(\.manager) var manager: BookmarksManager

    var selection: Binding<Tags?>
    var tag: Tags
    var title: String
    var systemImage: String
    var databaseView: DatabaseView

    func selectionActiveBinding(_ tag: Tags) -> Binding<Bool> {
        return Binding {
            selection.wrappedValue == tag
        } set: { value in
            guard value == true else {
                return
            }
            selection.wrappedValue = tag
        }
    }

    var body: some View {
        NavigationLink(destination: ContentView(sidebarSelection: selection, databaseView: databaseView)
                        .navigationTitle(title),
                       isActive: selectionActiveBinding(.allBookmarks)) {
            Label(title, systemImage: systemImage)
        }
        .tag(tag)
    }

}

struct Sidebar: View {

    // TOOD: Maybe the sidebar selection is an app manager thing, given it's probably top-level app state?

    enum SheetType {
        case rename(tag: String)
    }

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var tagsView: TagsView
    @ObservedObject var settings: BookmarksCore.Settings

    @State var selection: Tags? = .allBookmarks
    @State var sheet: SheetType? = nil

    func selectionActiveBinding(_ tag: Tags) -> Binding<Bool> {
        return Binding {
            self.selection == tag
        } set: { value in
            guard value == true else {
                return
            }
            self.selection = tag
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                SidebarLink(selection: $selection,
                            tag: .allBookmarks,
                            title: "All Bookmarks",
                            systemImage: "bookmark",
                            databaseView: DatabaseView(database: manager.database))
//                NavigationLink(destination: ContentView(sidebarSelection: $selection, databaseView: DatabaseView(database: manager.database))
//                                .navigationTitle("All Bookmarks"),
//                               isActive: selectionActiveBinding(.allBookmarks)) {
//                    Label("All Bookmarks", systemImage: "bookmark")
//                }
//                .tag(Tags.allBookmarks)
                NavigationLink(destination: ContentView(sidebarSelection: $selection, databaseView: DatabaseView(database: manager.database, tags: []))
                                .navigationTitle("Untagged"),
                               isActive: selectionActiveBinding(.untagged)) {
                    Label("Untagged", systemImage: "tag")
                }
                .tag(Tags.untagged)
            }
            Section(header: Text("Favourites")) {
                ForEach(settings.favoriteTags.sorted(), id: \.favoriteId) { tag in
                    NavigationLink(destination: ContentView(sidebarSelection: $selection, databaseView: DatabaseView(database: manager.database, tags: [tag]))
                                    .navigationTitle(tag),
                                   isActive: selectionActiveBinding(tag.favoriteId)) {
                        Label(tag, systemImage: "tag")
                    }
                    .contextMenu(ContextMenu(menuItems: {
                        Button("Remove from Favourites") {
                            settings.favoriteTags = settings.favoriteTags.filter { $0 != tag }
                        }
                        Divider()
                        Button("Edit on Pinboard") {
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
                }
            }
            Section(header: Text("Tags")) {
                ForEach(tagsView.tags, id: \.tagId) { tag in
                    NavigationLink(destination: ContentView(sidebarSelection: $selection, databaseView: DatabaseView(database: manager.database, tags: [tag]))
                                    .navigationTitle(tag),
                                   isActive: selectionActiveBinding(tag.tagId)) {
                        HStack {
                            Image(systemName: "tag")
                                .renderingMode(.template)
                                .foregroundColor(.secondary)
                            Text(tag)
                        }
                    }
                    .contextMenu(ContextMenu(menuItems: {
                        Button("Rename") {
                            self.sheet = .rename(tag: tag)
                        }
                        Button("Delete") {
                            self.manager.pinboard.tags_delete(tag) { _ in
                                self.manager.updater.start()
                            }
                        }
                        Divider()
                        Button("Add to Favourites") {
                            var favoriteTags = settings.favoriteTags
                            favoriteTags.append(tag)
                            settings.favoriteTags = favoriteTags
                        }
                        Divider()
                        Button("Edit on Pinboard") {
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
                }
            }

        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .rename(let tag):
                RenameTagView(tag: tag)
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
            print("selection = \(selection)")
        })
    }
}

extension Sidebar.SheetType: Identifiable {

    var id: String {
        switch self {
        case .rename(let tag):
            return "rename:\(tag)"
        }
    }

}
