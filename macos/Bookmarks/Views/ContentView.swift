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

enum LayoutMode: CaseIterable, Identifiable {

    var id: Self { self }

    case grid
    case table

    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .table:
            return "list.bullet"
        }
    }

    var help: String {
        return "THIS IS NEVER USED"
    }
}


struct LayoutToolbar: CustomizableToolbarContent {

    @Binding var layoutMode: LayoutMode

    var body: some CustomizableToolbarContent {

        ToolbarItem(id: "layout-mode") {
            Picker(selection: $layoutMode) {
                ForEach(LayoutMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .help(mode.help)
                        .tag(mode)
                }
            } label: {
            }
            .pickerStyle(.inline)
        }

    }

}

struct ContentView: View {

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus

    // TODO: Rename bookmarksView to ContentModel
    @StateObject var bookmarksView: BookmarksView
    // TODO: Rename to selection model?
    @StateObject var selection: BookmarksSelection = BookmarksSelection()
    @State var layoutMode: LayoutMode = .grid

    let layout = ColumnLayout(spacing: 2.0,
                              columns: 5,
                              edgeInsets: NSEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))

    init(section: BookmarksSection) {
        _bookmarksView = StateObject(wrappedValue: BookmarksView(section: section))
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
            switch layoutMode {
            case .grid:
                SelectableCollectionView(bookmarksView.bookmarks,
                                         selection: $selection.selection,
                                         layout: layout) { bookmark in

                    BookmarkCell(bookmark: bookmark)
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
                Table(bookmarksView.bookmarks, selection: $selection.selection) {
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
        .toolbar(id: "main") {
            LayoutToolbar(layoutMode: $layoutMode)
            AccountToolbar()
//            SelectionToolbar(selection: selection)
        }
        .navigationTitle(bookmarksView.title)
        .navigationSubtitle(bookmarksView.subtitle)
        .focusedValue(\.selection, selection)
    }
}
