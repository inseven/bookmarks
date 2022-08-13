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

struct ContentView: View {

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus

    @ObservedObject var selection: BookmarksSelection
    @ObservedObject var windowModel: WindowModel
    @Binding var sheet: ApplicationState?

    @StateObject var bookmarksView: BookmarksView
    @StateObject var selectionTracker: SelectionTracker<Bookmark>
    @State var firstResponder: Bool = false
    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))

    @State var tokens: [String] = []
    @State var suggestedTokens: [String] = []

    private var subscription: AnyCancellable?

    init(selection: BookmarksSelection,
         windowModel: WindowModel,
         database: Database,
         sheet: Binding<ApplicationState?>) {
        self.selection = selection
        self.windowModel = windowModel
        let bookmarksView = Deferred(BookmarksView(database: database, query: True().eraseToAnyQuery()))
        let selectionTracker = Deferred(SelectionTracker(items: bookmarksView.get().$bookmarks))
        _bookmarksView = StateObject(wrappedValue: bookmarksView.get())
        _selectionTracker = StateObject(wrappedValue: selectionTracker.get())
        _sheet = sheet
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(bookmarksView.bookmarks) { bookmark in
                        BookmarkCell(bookmark: bookmark)
                            .shadow(color: .shadow, radius: 8)
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: bookmark),
                                                        firstResponder: firstResponder))
                            .help(bookmark.url.absoluteString)
                            .contextMenuFocusable {
                                BookmarkOpenCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkDesctructiveCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkEditCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkShareCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkTagCommands(selection: selection)
                                #if DEBUG
                                BookmarkDebugCommands()
                                    .leadingDivider()
                                #endif
                            } onContextMenuChange: { focused in
                                guard focused == true else {
                                    return
                                }
                                firstResponder = true
                                if !selectionTracker.isSelected(item: bookmark) {
                                    selectionTracker.handleClick(item: bookmark)
                                }
                            }
                            .menuType(.context)
                            .onDrag {
                                NSItemProvider(object: bookmark.url as NSURL)
                            }
                            .handleMouse {
                                if firstResponder || !selectionTracker.isSelected(item: bookmark) {
                                    selectionTracker.handleClick(item: bookmark)
                                }
                                firstResponder = true
                            } doubleClick: {
                                NSWorkspace.shared.open(bookmark.url)
                            } shiftClick: {
                                selectionTracker.handleShiftClick(item: bookmark)
                            } commandClick: {
                                selectionTracker.handleCommandClick(item: bookmark)
                            }
                    }
                }
                .padding()
            }
            .acceptsFirstResponder(isFirstResponder: $firstResponder)
            .handleMouse {
                firstResponder = true
                selectionTracker.clear()
            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(bookmarksView.state == .loading ? LoadingView() : nil)
        }
        .onAppear {
            bookmarksView.start()
        }
        .onDisappear {
            bookmarksView.stop()
        }
        .searchable(text: $searchDebouncer.value, tokens: $tokens, suggestedTokens: $suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
        .toolbar(id: "main") {
            AccountToolbar()
            SelectionToolbar(selection: selection)
        }
        .onReceive(searchDebouncer.$debouncedValue) { search in

            guard let section = windowModel.section else {
                return
            }

            // Update the suggestions.
            if search.count > 0 {
                self.suggestedTokens = manager.tagsView.tags(prefix: search)
            } else {
                self.suggestedTokens = []
            }

            // Update the view.
            let queries = AnyQuery.queries(for: search)
            let tags = self.tokens.map { Tag($0).eraseToAnyQuery() }
            bookmarksView.query = AnyQuery.and([section.query] + queries + tags)
        }
        .onChange(of: windowModel.section) { section in

            guard let section = section else {
                return
            }

            tokens = []
            searchDebouncer.value = ""

            selectionTracker.clear()
            bookmarksView.clear()
            bookmarksView.query = section.query.eraseToAnyQuery()

        }
        .onChange(of: selectionTracker.selection) { newSelection in
            selection.bookmarks = newSelection
        }
        .navigationTitle(windowModel.title)
    }
}
