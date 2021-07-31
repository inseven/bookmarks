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

    enum SheetType {
        case rename(tag: String)
    }

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var tagsView: TagsView
    @ObservedObject var settings: BookmarksCore.Settings

    @Binding var selection: BookmarksSection?

    @State var sheet: SheetType? = nil

    var body: some View {
        ScrollViewReader { scrollView in
            List(selection: $selection) {
                Section {

                    SidebarLink(selection: $selection,
                                tag: .all,
                                title: "All Bookmarks",
                                systemImage: "bookmark.fill",
                                databaseView: ItemsView(database: manager.database))

                    SidebarLink(selection: $selection,
                                tag: .today,
                                title: "Today",
                                systemImage: "sun.max.fill",
                                databaseView: ItemsView(database: manager.database, query: Today()))

                    SidebarLink(selection: $selection,
                                tag: .shared,
                                title: "Public",
                                systemImage: "globe",
                                databaseView: ItemsView(database: manager.database, query: Shared()))


                    SidebarLink(selection: $selection,
                                tag: .unread,
                                title: "Unread",
                                systemImage: "circlebadge.fill",
                                databaseView: ItemsView(database: manager.database, query: Unread()))

                    SidebarLink(selection: $selection,
                                tag: .untagged,
                                title: "Untagged",
                                systemImage: "tag.fill",
                                databaseView: ItemsView(database: manager.database, query: Untagged()))

                }
                Section(header: Text("Favourites")) {
                    ForEach(settings.favoriteTags.sorted(), id: \.favoriteId) { tag in

                        SidebarLink(selection: $selection,
                                    tag: tag.favoriteId,
                                    title: tag,
                                    systemImage: "tag",
                                    databaseView: ItemsView(database: manager.database, query: Tag(tag)))
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

                        SidebarLink(selection: $selection,
                                    tag: tag.tagId,
                                    title: tag,
                                    systemImage: "tag",
                                    databaseView: ItemsView(database: manager.database, query: Tag(tag)))
                            .contextMenu(ContextMenu(menuItems: {
                                Button("Rename") {
                                    self.sheet = .rename(tag: tag)
                                }
                                Button("Delete") {
                                    self.manager.database.deleteTag(tag: tag, completion: { _ in })
                                    self.manager.pinboard.tagsDelete(tag) { _ in
                                        self.manager.refresh()
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
            .onChange(of: selection) { selection in
                guard let selection = selection else {
                    return
                }
                print("scrolling to \(selection)")
                scrollView.scrollTo(selection)
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
