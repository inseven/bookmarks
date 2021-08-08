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

// TODO: Inject the colors
// TODO: Inject the border radius

struct BorderedSelection: ViewModifier {

    @Environment(\.applicationHasFocus) var applicationHasFocus

    var selected: Bool

    func body(content: Content) -> some View {
        if selected {
            content
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(applicationHasFocus ? Color.accentColor : Color.unemphasizedSelectedContentBackgroundColor, lineWidth: 3))

        } else {
            content
                .padding(4)
        }
    }

}


struct AddTagsView: View {

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.manager) var manager: BookmarksManager
    var items: [Item]
    @State var isBusy = false

    @State var tokens: [Token<String>] = []  // TODO: Support a payload on the tokens.

    @StateObject var tagsView: TagsView
    @State var trie = Trie()

    init(database: Database, items: [Item]) {
        _tagsView = StateObject(wrappedValue: TagsView(database: database))
        self.items = items
    }

    var characterSet: CharacterSet {
        let characterSet = NSTokenField.defaultTokenizingCharacterSet
        let spaceCharacterSet = CharacterSet(charactersIn: " ")
        return characterSet.union(spaceCharacterSet)
    }

    // TODO: Default focus when launching.
    var body: some View {
        Form {
            Section {
                TokenField("Add tags...", tokens: $tokens) { string in
                    let tag = string.lowercased()
                    return Token(tag)
                        .associatedValue(tag)
                } completions: { substring in
                    trie.findWordsWithPrefix(prefix: substring)
                }
                .tokenizingCharacterSet(characterSet)
                .font(.title)
                .frame(minWidth: 400)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("OK") {
                        isBusy = true
                        let tags = tokens.compactMap { $0.associatedValue }
                        for item in items {
                            let item = item
                                .adding(tags: Set(tags))
                                .setting(toRead: false)  // TODO: This is a hack that should be removed (maybe make it an option?)
                            manager.updateItem(item, completion: { _ in })
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 200)
        .padding()
        .disabled(isBusy)
        .onAppear {
            tagsView.start()
        }
        .onDisappear {
            tagsView.stop()
        }
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

    }

}

extension Item: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

}

struct ContentView: View {

    enum SheetType {
        case addTags(items: [Item])
    }

    @Binding var sidebarSelection: BookmarksSection?
    @State var underlyingSection: BookmarksSection?

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var databaseView: ItemsView
    @StateObject var tagsView: TagsView

    @StateObject var selectionTracker: SelectionTracker<Item>

    @State var trie = Trie()

    @StateObject var tokenDebouncer = Debouncer<[Token<String>]>(initialValue: [], delay: .seconds(0.2))

    @State var sheet: SheetType? = nil

    private var subscription: AnyCancellable?

    init(sidebarSelection: Binding<BookmarksSection?>, database: Database) {
        _sidebarSelection = sidebarSelection
        _tagsView = StateObject(wrappedValue: TagsView(database: database))

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
                            .onDrag {
                                NSItemProvider(object: item.url as NSURL)
                            }
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: item)))
                            .help(item.localDate)
                            .handleMouse {
                                print("click")
                                selectionTracker.handleClick(item: item)
                                manager.database.item(identifier: item.identifier) { result in
                                    switch result {
                                    case .success(let item):
                                        print(String(describing: item))
                                    case .failure(let error):
                                        print("failed to get item with error \(error)")
                                    }
                                }
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
                            .contextMenu {
                                BookmarkOpenCommands(item: item)
                                Divider()
                                BookmarkDesctructiveCommands(item: item)
                                Divider()
                                BookmarkEditCommands(item: item)
                                // TODO: Move this into the bookmark edit commands
                                Button("Add tags...") {
                                    self.sheet = .addTags(items: [item])
                                }
                                Divider()
                                BookmarkShareCommands(item: item)
                                Divider()
                                BookmarkTagCommands(sidebarSelection: $sidebarSelection, item: item)
                            }
                    }
                }
                .padding()
            }
            .handleMouse {
                selectionTracker.clear()
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
                    sheet = .addTags(items: Array(selectionTracker.selection))
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
                TokenField("Search", tokens: $tokenDebouncer.value) { string in
                    Token(string)
                        .tokenStyle(tagsView.tags.contains(string) ? .default : .none)
                        .associatedValue(tagsView.tags.contains(string) ? "tag:\(string)" : string)
                } completions: { substring in
                    trie.findWordsWithPrefix(prefix: substring)
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
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .addTags(let items):
                AddTagsView(database: manager.database, items: items)
            }
        }
        .navigationTitle(navigationTitle)
    }
}

extension ContentView.SheetType: Identifiable {

    var id: String {
        switch self {
        case .addTags(let items):
            return "addTags:\(items.map { $0.identifier }.joined(separator: ","))"
        }
    }

}
