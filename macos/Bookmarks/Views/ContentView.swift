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

extension Item {

    var localDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .long
        return "Added \(dateFormatter.string(from: date))"
    }

}

struct ContentView: View {

    @Binding var sidebarSelection: BookmarksSection?
    @State var underlyingSection: BookmarksSection?

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus
    @Environment(\.sheetHandler) var sheetHandler
    @StateObject var databaseView: ItemsView
    @ObservedObject var tagsView: TagsView

    @StateObject var selectionTracker: SelectionTracker<Item>
    @State var firstResponder: Bool = false

    @StateObject var tokenDebouncer = Debouncer<[Token<String>]>(initialValue: [], delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(sidebarSelection: Binding<BookmarksSection?>, database: Database, tagsView: TagsView) {
        _sidebarSelection = sidebarSelection
        self.tagsView = tagsView
        let databaseView = Deferred(ItemsView(database: database, query: True().eraseToAnyQuery()))
        let selectionTracker = Deferred(SelectionTracker(items: databaseView.get().$items))
        _databaseView = StateObject(wrappedValue: databaseView.get())
        _selectionTracker = StateObject(wrappedValue: selectionTracker.get())
    }

    var navigationTitle: String {
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
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: item), firstResponder: firstResponder))
                            .help(item.localDate)
                            .contextMenuFocusable {
                                BookmarkOpenCommands(selection: $selectionTracker.selection)
                                Divider()
                                BookmarkDesctructiveCommands(selection: $selectionTracker.selection)
                                Divider()
                                BookmarkEditCommands(selection: $selectionTracker.selection)
                                Divider()
                                BookmarkShareCommands(item: item)
                                Divider()
                                BookmarkTagCommands(sidebarSelection: $sidebarSelection, item: item)
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
                                print("click")
                                if firstResponder || !selectionTracker.isSelected(item: item) {
                                    selectionTracker.handleClick(item: item)
                                }
                                firstResponder = true
                            } doubleClick: {
                                print("double click")
                                NSWorkspace.shared.open(item.url)
                            } shiftClick: {
                                print("shift click")
                                selectionTracker.handleShiftClick(item: item)
                            } commandClick: {
                                print("command click")
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
            .preference(key: SelectionPreferenceKey.self, value: firstResponder ? selectionTracker.selection : [])
            .overlay(databaseView.state == .loading ? LoadingView() : nil)
        }
        .onAppear {
            databaseView.start()
            tagsView.start() // TODO: App wide view?
        }
        .onDisappear {
            databaseView.stop()
            tagsView.stop()
        }
        .toolbar {

            ToolbarItem {
                Button {
                    manager.refresh(force: true)
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                }
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
                    for item in selectionTracker.selection {
                        manager.deleteItem(item, completion: { _ in })
                    }
                } label: {
                    SwiftUI.Image(systemName: "trash")
                }
                .help("Add Tags")
                .disabled(selectionTracker.selection.count == 0)
            }

            ToolbarItem {
                TokenField("Search", tokens: $tokenDebouncer.value) { string, editing in
                    Token(string)
                        .tokenStyle(tagsView.contains(tag: string) ? .default : .none)
                        .associatedValue(tagsView.contains(tag: string) && !editing ? "tag:\(string)" : string)
                } completions: { substring in
                    tagsView.tags(prefix: substring)
                }
                .font(.title3)
                .lineLimit(1)
                .wraps(false)
                .frame(minWidth: 400)
            }

        }
        .onReceive(tokenDebouncer.$debouncedValue) { tokens in

            let queries = tokens.compactMap { token in
                token.associatedValue
            }.map {
                AnyQuery.parse(token: $0)
            }

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
            databaseView.query = query.eraseToAnyQuery()

            // TODO: We're doing unnecessary round-trips here.
            let tokens = AnyQuery.queries(for: query.filter).map { query in
                Token(query.filter)
                    .displayString(query.displayString)
                    .associatedValue(query.filter)
            }

            self.tokenDebouncer.value = tokens

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
