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

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var databaseView: ItemsView
    @StateObject var tagsView: TagsView

    @State var trie = Trie()

    @StateObject var tokenDebouncer = Debouncer<[Token<String>]>(initialValue: [], delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(sidebarSelection: Binding<BookmarksSection?>, database: Database) {
        _sidebarSelection = sidebarSelection
        _databaseView = StateObject(wrappedValue: ItemsView(database: database, query: True().eraseToAnyQuery()))
        _tagsView = StateObject(wrappedValue: TagsView(database: database))
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(databaseView.items) { item in
                        BookmarkCell(item: item)
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
                                BookmarkOpenCommands(item: item)
                                Divider()
                                BookmarkDesctructiveCommands(item: item)
                                Divider()
                                BookmarkEditCommands(item: item)
                                Divider()
                                BookmarkShareCommands(item: item)
                                Divider()
                                BookmarkTagCommands(sidebarSelection: $sidebarSelection, item: item)
                            }
                            .onDrag {
                                NSItemProvider(object: item.url as NSURL)
                            }
                    }
                }
                .padding()
            }
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
                    manager.refresh()
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem {
                TokenField("Search", tokens: $tokenDebouncer.value) { string in
                    Token(string)
                        .tokenStyle(tagsView.tags.contains(string) ? .default : .none)
                        .associatedValue(tagsView.tags.contains(string) ? "tag:\(string)" : string)
                } completions: { substring in
                    trie.findWordsWithPrefix(prefix: substring)
                }
                .font(.title3)
                .lineLimit(1)
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
        .onReceive(tagsView.$tags) { tags in
            DispatchQueue.global(qos: .background).async {
                let trie = Trie()
                for tag in tags {
                    trie.insert(word: tag)
                }
                DispatchQueue.main.async {
                    self.trie = trie
                }
            }
        }
        .navigationTitle(navigationTitle)
    }
}
