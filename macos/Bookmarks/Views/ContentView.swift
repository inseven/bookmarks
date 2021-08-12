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

struct ContentView: View {

    @Binding var sidebarSelection: BookmarksSection?
    @State var underlyingSection: BookmarksSection?

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus
    @Environment(\.sheetHandler) var sheetHandler
    @Environment(\.errorHandler) var errorHandler
    @StateObject var databaseView: ItemsView

    @StateObject var selectionTracker: SelectionTracker<Item>
    @State var firstResponder: Bool = false

    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(sidebarSelection: Binding<BookmarksSection?>, database: Database) {
        _sidebarSelection = sidebarSelection
        let databaseView = Deferred(ItemsView(database: database, query: True().eraseToAnyQuery()))
        let selectionTracker = Deferred(SelectionTracker(items: databaseView.get().$items))
        _databaseView = StateObject(wrappedValue: databaseView.get())
        _selectionTracker = StateObject(wrappedValue: selectionTracker.get())
    }

    var navigationTitle: String {
        let queries = searchDebouncer.debouncedValue.queries
        if (queries.section == .all && queries.count > 1) || queries.count > 1 {
            return "Search: \(searchDebouncer.debouncedValue)"
        }
        guard let title = sidebarSelection?.navigationTitle else {
            return "Unknown"
        }
        return title
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(databaseView.items) { item in
                        BookmarkCell(item: item)
                            .shadow(color: .shadow, radius: 8)
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: item), firstResponder: firstResponder))
                            .help(item.localDate)
                            .contextMenuFocusable {
                                BookmarkOpenCommands(selection: $selectionTracker.selection)
                                    .trailingDivider()
                                BookmarkDesctructiveCommands(selection: $selectionTracker.selection)
                                    .trailingDivider()
                                BookmarkEditCommands(selection: $selectionTracker.selection)
                                    .trailingDivider()
                                BookmarkShareCommands(item: item)
                                    .trailingDivider()
                                BookmarkTagCommands(sidebarSelection: $sidebarSelection, selection: $selectionTracker.selection)
                                #if DEBUG
                                BookmarkDebugCommands()
                                    .leadingDivider()
                                #endif
                            } onContextMenuChange: { focused in
                                guard focused == true else {
                                    return
                                }
                                firstResponder = true
                                if !selectionTracker.isSelected(item: item) {
                                    selectionTracker.handleClick(item: item)
                                }
                            }
                            .onDrag {
                                NSItemProvider(object: item.url as NSURL)
                            }
                            .handleMouse {
                                if firstResponder || !selectionTracker.isSelected(item: item) {
                                    selectionTracker.handleClick(item: item)
                                }
                                firstResponder = true
                            } doubleClick: {
                                NSWorkspace.shared.open(item.url)
                            } shiftClick: {
                                selectionTracker.handleShiftClick(item: item)
                            } commandClick: {
                                selectionTracker.handleCommandClick(item: item)
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
            .overlay(databaseView.state == .loading ? LoadingView() : nil)
        }
        .onAppear {
            databaseView.start()
        }
        .onDisappear {
            databaseView.stop()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    manager.refresh()
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ToolbarItem {
                Button {
                    guard selectionTracker.selection.count > 0 else {
                        return
                    }
                    sheetHandler(.addTags(items: Array(selectionTracker.selection)))
                } label: {
                    SwiftUI.Image(systemName: "tag")
                }
                .help("Add Tags")
                .disabled(selectionTracker.selection.count == 0)
            }
            ToolbarItem {
                Button {
                    manager.deleteItems(Array(selectionTracker.selection)) { result in
                        guard case .failure(let error) = result else {
                            return
                        }
                        errorHandler(error)
                    }
                } label: {
                    SwiftUI.Image(systemName: "trash")
                }
                .help("Delete")
                .disabled(selectionTracker.selection.count == 0)
            }

            ToolbarItem {
                SearchField(search: $searchDebouncer.value)
                    .frame(minWidth: 100, idealWidth: 300, maxWidth: .infinity)
            }
        }
        .onReceive(searchDebouncer.$debouncedValue) { search in

            // Get the query corresponding to the current search text.
            let queries = AnyQuery.queries(for: search)

            // Update the selected section if necessary.
            let section = queries.section
            if section != sidebarSelection {
                underlyingSection = section
            }

            // Update the database query.
            databaseView.query = AnyQuery.and(queries)

        }
        .onChange(of: sidebarSelection) { section in

            guard underlyingSection != section,
                  let section = section else {
                return
            }

            underlyingSection = section

            selectionTracker.clear()
            databaseView.clear()
            let query = section.query
            searchDebouncer.value = query.filter
            databaseView.query = query.eraseToAnyQuery()

        }
        .onChange(of: underlyingSection, perform: { underlyingSection in

            guard sidebarSelection != underlyingSection else {
                return
            }

            // Bring the sidebar section in-line with the underlying section.
            sidebarSelection = underlyingSection

        })
        .navigationTitle(navigationTitle)
    }
}
