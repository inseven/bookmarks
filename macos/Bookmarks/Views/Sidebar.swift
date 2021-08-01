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

extension BookmarksSection {

    var query: AnyQuery {
        switch self {
        case .all:
            return True().eraseToAnyQuery()
        case .untagged:
            return Untagged().eraseToAnyQuery()
        case .today:
            return Today().eraseToAnyQuery()
        case .unread:
            return Unread().eraseToAnyQuery()
        case .shared(let shared):
            return Shared(shared).eraseToAnyQuery()
        case .favorite(tag: let tag):
            return Tag(tag).eraseToAnyQuery()
        case .tag(tag: let tag):
            return Tag(tag).eraseToAnyQuery()
        }
    }

    var navigationTitle: String {
        switch self {
        case .all:
            return "All Bookmarks"
        case .untagged:
            return "Untagged"
        case .today:
            return "Today"
        case .unread:
            return "Unread"
        case .shared(let shared):
            if shared {
                return "Public"
            } else {
                return "Private"
            }
        case .favorite(tag: let tag):
            return tag
        case .tag(tag: let tag):
            return tag
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "bookmark.fill"
        case .untagged:
            return "tag.fill"
        case .today:
            return "sun.max.fill"
        case .unread:
            return "circlebadge.fill"
        case .shared(let shared):
            if shared {
                return "globe"
            } else {
                return "lock.fill"
            }
        case .favorite:
            return "tag"
        case .tag:
            return "tag"
        }
    }

}

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

                Section(header: Text("Smart Filters")) {

                    SidebarLink(selection: $selection,
                                tag: .all,
                                query: True().eraseToAnyQuery())

                    SidebarLink(selection: $selection,
                                tag: .shared(false),
                                query: Shared(false).eraseToAnyQuery())

                    SidebarLink(selection: $selection,
                                tag: .shared(true),
                                query: Shared(true).eraseToAnyQuery())

                    SidebarLink(selection: $selection,
                                tag: .today,
                                query: Today().eraseToAnyQuery())

                    SidebarLink(selection: $selection,
                                tag: .unread,
                                query: Unread().eraseToAnyQuery())

                    SidebarLink(selection: $selection,
                                tag: .untagged,
                                query: Untagged().eraseToAnyQuery())

                }
                Section(header: Text("Favourites")) {
                    ForEach(settings.favoriteTags.sorted(), id: \.favoriteId) { tag in

                        SidebarLink(selection: $selection,
                                    tag: tag.favoriteId,
                                    query: Tag(tag).eraseToAnyQuery())
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
                                        NSWorkspace.shared.open(try tag.pinboardTagUrl(for: user))
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
                                    query: Tag(tag).eraseToAnyQuery())
                            .contextMenu(ContextMenu(menuItems: {
                                Button("Rename") {
                                    self.sheet = .rename(tag: tag)
                                }
                                Button("Delete") {
                                    self.manager.deleteTag(tag: tag) { _ in }
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
                                        NSWorkspace.shared.open(try tag.pinboardTagUrl(for: user))
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
