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

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var databaseView: ItemsView

    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(sidebarSelection: Binding<BookmarksSection?>, database: Database) {
        _sidebarSelection = sidebarSelection
        _databaseView = StateObject(wrappedValue: ItemsView(database: database, query: True().eraseToAnyQuery()))
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(databaseView.items) { item in
                        BookmarkCell(item: item)
                            .shadow(color: .shadow, radius: 8)
                            .help(item.localDate)
                            .onClick {
                                manager.database.item(identifier: item.identifier) { result in
                                    switch result {
                                    case .success(let item):
                                        print(String(describing: item))
                                    case .failure(let error):
                                        print("failed to get item with error \(error)")
                                    }
                                }
                            } doubleClick: {
                                NSWorkspace.shared.open(item.url)
                            }
                            .onCommandDoubleClick {
                                do {
                                    NSWorkspace.shared.open(try item.pinboardUrl())
                                } catch {
                                    print("Failed to edit with error \(error)")
                                }
                            }
                            .contextMenu {
                                BookmarkOpenCommands(selection: Binding.constant(Set([item])))
                                    .trailingDivider()
                                BookmarkDesctructiveCommands(selection: Binding.constant(Set([item])))
                                    .trailingDivider()
                                BookmarkEditCommands(selection: Binding.constant(Set([item])))
                                    .trailingDivider()
                                BookmarkShareCommands(item: item)
                                    .trailingDivider()
                                BookmarkTagCommands(sidebarSelection: $sidebarSelection, item: item)
                                #if DEBUG
                                BookmarkDebugCommands()
                                    .leadingDivider()
                                #endif
                            }
                            .onDrag {
                                NSItemProvider(object: item.url as NSURL)
                            }
                    }
                }
                .padding()
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
