// Copyright (c) 2020-2022 InSeven Limited
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
import SelectableCollectionView

struct ContentView: View {

    let manager: BookmarksManager

    @EnvironmentObject var windowModel: WindowModel

    // TODO: Rename bookmarksView to ContentModel
    @StateObject var bookmarksView: BookmarksView

    let layout = ColumnLayout(spacing: 2.0,
                              columns: 5,
                              edgeInsets: NSEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))

    init(manager: BookmarksManager, section: BookmarksSection) {
        self.manager = manager
        _bookmarksView = StateObject(wrappedValue: BookmarksView(manager: manager, section: section))
    }

    @MenuItemBuilder private func contextMenu(_ selection: Set<Bookmark.ID>) -> [MenuItem] {
        MenuItem("Open") {
            manager.open(await bookmarksView.bookmarks(for: selection))
        }
        MenuItem("Open on Internet Archive") {
            manager.open(await bookmarksView.bookmarks(for: selection), location: .internetArchive)
        }
        Separator()
        MenuItem("Delete") {
            do {
                try await manager.deleteBookmarks(await bookmarksView.bookmarks(for: selection))
            } catch {
                print("Failed to delete bookmarks with error \(error)")
            }
        }
//        BookmarkOpenCommands(selection: selection)
//            .trailingDivider()
//        BookmarkDesctructiveCommands(selection: selection)
//            .trailingDivider()
//        BookmarkEditCommands(selection: selection)
//            .trailingDivider()
//        BookmarkShareCommands(selection: selection)
//            .trailingDivider()
//        BookmarkTagCommands(selection: selection)
//        #if DEBUG
//        BookmarkDebugCommands()
//            .leadingDivider()
//        #endif
    }

    @MainActor func primaryAction(_ selection: Set<Bookmark.ID>) {
        bookmarksView.open(ids: selection)
    }

    var body: some View {
        VStack {

            switch bookmarksView.layoutMode {
            case .grid:
                SelectableCollectionView(bookmarksView.bookmarks,
                                         selection: $bookmarksView.selection,
                                         layout: layout) { bookmark in

                    BookmarkCell(manager: manager, bookmark: bookmark)
                        .modifier(BorderedSelection())
                        .padding(4.0)
                        .shadow(color: .shadow, radius: 4.0)
                        .help(bookmark.url.absoluteString)

                } contextMenu: { selection in
                    contextMenu(selection)
                } primaryAction: { selection in
                    primaryAction(selection)
                }
            case .table:

                Table(bookmarksView.bookmarks, selection: $bookmarksView.selection) {
                    TableColumn("Title", value: \.title)
                    TableColumn("URL", value: \.url.absoluteString)
                    TableColumn("Tags") { bookmark in
                        Text(bookmark.tags.joined(separator: " "))
                    }
                }
                .contextMenu(forSelectionType: Bookmark.ID.self) { selection in
                    contextMenu(selection)
                } primaryAction: { selection in
                    primaryAction(selection)
                }
            }

        }
        .overlay(bookmarksView.state == .loading ? LoadingView() : nil)
        .onAppear {
            bookmarksView.start()
        }
        .onDisappear {
            bookmarksView.stop()
        }
        .searchable(text: $bookmarksView.filter,
                    tokens: $bookmarksView.tokens,
                    suggestedTokens: $bookmarksView.suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
        .navigationTitle(bookmarksView.title)
        .navigationSubtitle(bookmarksView.subtitle)
        .sheet(item: $bookmarksView.sheet) { sheet in
            switch sheet {
            case .addTags:
                EditView(tagsView: manager.tagsView, bookmarksView: bookmarksView)
            }
        }
        .presents($bookmarksView.lastError)
        .focusedSceneObject(bookmarksView)
    }
}
