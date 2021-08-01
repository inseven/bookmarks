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

// TODO: Initial value? + Updateable
class TextFieldObserver : ObservableObject {
    @Published var debouncedText = ""
    @Published var searchText = ""

    private var subscriptions = Set<AnyCancellable>()

    init() {
        $searchText
            // TODO: Way too long!
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .sink(receiveValue: { t in
                self.debouncedText = t
            } )
            .store(in: &subscriptions)
    }
}

struct ContentView: View {

    @Binding var sidebarSelection: BookmarksSection?
    @State var underlyingSection: BookmarksSection?  // The section currently being displayed (used to ignore incoming changes)

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var databaseView: ItemsView
    var query: AnyQuery = True().eraseToAnyQuery()

    @StateObject var textObserver = TextFieldObserver()

    private var subscription: AnyCancellable?

    init(sidebarSelection: Binding<BookmarksSection?>, database: Database) {
        _sidebarSelection = sidebarSelection
        // TODO: Initializaiton is broken here
        _databaseView = StateObject(wrappedValue: ItemsView(database: database, query: True().eraseToAnyQuery()))
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
            }
            ToolbarItem {
                SearchField(search: $textObserver.searchText)
                    .frame(minWidth: 100, idealWidth: 300, maxWidth: .infinity)
            }
        }
        .onReceive(textObserver.$debouncedText) { search in
//            let filter = parseFilter(search)
//            print("section = \(filter.section)")
            // TODO: Save the structured thing in the search?
//            databaseView.search = filter.eraseToAnyQuery()
//            if sidebarSelection != filter.section {
//                sidebarSelection = filter.section
//            }

            guard let selection = sidebarSelection else {
                print("BROKEN: Ignoring nil sidebar")
                return
            }

            // Don't set the query unless the top level token has been removed.
            // TODO: Utility to determine if the array describes the current section uniquely
            let queries = filterQueries(search)
            if !queries.subset(of: selection) {
                let nextSection = queries.section
                underlyingSection = nextSection
                // TODO: Maybe do this as a side effect of changing the underlyingSection?
                if sidebarSelection != nextSection {
                    sidebarSelection = nextSection
                }
            }
            databaseView.search = safeAnd(queries: queries).eraseToAnyQuery()
        }
        .onChange(of: sidebarSelection) { section in

            guard underlyingSection != section,
                  let section = section else {
                return
            }

            underlyingSection = section
            databaseView.clear() // TODO: Replace with a new view??
            // TODO: Switch the section if the first query is different? Would probably look more elegant / predictible?

            print("new section = \(section)")
            switch section {
            case .search(let filter):
                // TODO: Simple subset check that means we don't change the top-level navigation.
                textObserver.searchText = filter
                databaseView.search = parseFilter(filter).eraseToAnyQuery()
            default:
                let query = section.query
                textObserver.searchText = query.filter
                databaseView.search = query.eraseToAnyQuery()
            }
        }
        .navigationTitle(sidebarSelection?.navigationTitle ?? "Unknown")
    }
}

extension Array where Element == AnyQuery {

    var sections: Set<BookmarksSection> {
        Set(map { $0.section })
    }

    func subset(of section: BookmarksSection) -> Bool {
        sections.contains(section)
    }

    func exactlyMatches(section: BookmarksSection) -> Bool {
        let sections = sections
        guard sections.count == 1,
              let testSection = sections.first else {
            return false
        }
        return section == testSection
    }

    var section: BookmarksSection {
        guard sections.count == 1,
              let section = sections.first else {
            return .all
        }
        return section
    }

}

extension And {

    // TODO: Var?
    // TODO: Walk the tree?
    func subQueries() -> [AnyQuery] {
        return [lhs.eraseToAnyQuery(), rhs.eraseToAnyQuery()]
    }

}

//extension QueryDescription {
//
//    func subset(of section: BookmarksSection) -> Bool {
//        let querySection = self.section
//        if querySection == section {
//            return true
//        }
//        guard let andQuery = self.query as? And else {
//            return false
//        }
//        return false
//    }
//
//}
