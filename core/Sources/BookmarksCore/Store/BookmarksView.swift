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
import Foundation
import SwiftUI

import Interact

public class BookmarksView: ObservableObject {

    public enum SheetType: Identifiable {

        public var id: Self { self }

        case addTags
    }

    public enum State {
        case loading
        case ready
    }

    @Environment(\.openURL) private var openURL

    @Published public var title: String
    @Published public var subtitle: String = ""
    @Published public var bookmarks: [Bookmark] = []
    @Published public var state: State = .loading
    @Published public var filter: String = ""
    @Published public var tokens: [String] = []
    @Published public var suggestedTokens: [String] = []
    @Published public var layoutMode: LayoutMode = .grid
    @Published public var selection: Set<Bookmark.ID> = []

    @Published public var sheet: SheetType? = nil
    @Published public var lastError: Error? = nil

    @Published private var query: AnyQuery

    private let manager: BookmarksManager
    private let section: BookmarksSection
    private var cancellables: Set<AnyCancellable> = []
    private let queryQueue = DispatchQueue(label: "queryQueue")

    public init(manager: BookmarksManager, section: BookmarksSection) {
        self.manager = manager
        self.section = section
        self.query = section.query
        self.title = section.navigationTitle
    }

    @MainActor public func start() {

        // Set up the initial state (in case we are being reused).
        bookmarks = []
        state = .loading

        // Query the database whenever a change occurs or the query changes.
        DatabasePublisher(database: manager.database)
            .prepend(())
            .combineLatest($query)
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.global())
            .asyncMap { (_, query) in
                do {
                    return (query, try await self.manager.database.bookmarks(query: query))
                } catch {
                    return (query, [])
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { query, bookmarks in
                // Guard against updating the bookmarks with results from an old query.
                guard self.query == query else {
                    print("Discarding query")
                    return
                }
                self.bookmarks = bookmarks
                self.state = .ready
            }
            .store(in: &cancellables)

        // Update the active query when the section, filter, or tokens change.
        $filter
            .combineLatest($tokens)
            .map { (filter, tokens) in
                let tokensQuery = tokens.map { Tag($0).eraseToAnyQuery() }
                let filterQuery = AnyQuery.queries(for: filter)
                return AnyQuery.and([self.section.query] + tokensQuery + filterQuery)
            }
            .receive(on: DispatchQueue.main)
            .sink { query in
                self.query = query
            }
            .store(in: &cancellables)

        // Update the suggested tokens.
        manager.tagsView.$trie
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .combineLatest($filter)
            .receive(on: DispatchQueue.global())
            .map { trie, filter in
                guard !filter.isEmpty else {
                    return []
                }
                // SwiftUI gets quite upset if we return too many token suggestions, so we limit this to 10.
                return Array(trie.findWordsWithPrefix(prefix: filter).prefix(10))
            }
            .receive(on: DispatchQueue.main)
            .sink { tags in
                self.suggestedTokens = tags
            }
            .store(in: &cancellables)

        // Update the title.
        $filter
            .combineLatest($tokens)
            .receive(on: DispatchQueue.main)
            .sink { filter, tokens in
                print(filter)
                if filter.isEmpty && tokens.isEmpty {
                    self.title = self.section.navigationTitle
                } else {
                    self.title = "Searching \"\(self.section.navigationTitle)\""
                }
            }
            .store(in: &cancellables)

        // Update the subtitle.
        $bookmarks
            .combineLatest($state)
            .receive(on: DispatchQueue.main)
            .sink { bookmarks, state in
                switch state {
                case .loading:
                    self.subtitle = ""
                case .ready:
                    self.subtitle = "\(bookmarks.count) items"
                }
            }
            .store(in: &cancellables)
    }

    @MainActor public func stop() {
        cancellables.removeAll()
    }

    @MainActor public func addTags() {
        sheet = .addTags
    }

    @MainActor public func bookmarks(for ids: Set<Bookmark.ID>? = nil) async -> [Bookmark] {
        let ids = ids ?? self.selection
        let bookmarks = bookmarks
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: bookmarks.filter { ids.contains($0.id) })
            }
        }
    }

    @MainActor public func open(ids: Set<Bookmark.ID>? = nil, location: Bookmark.Location = .web) {
        let ids = ids ?? self.selection
        let bookmarks = bookmarks
        DispatchQueue.global(qos: .userInitiated).async {
            let selectedBookmarks = bookmarks.filter { ids.contains($0.id) }
            DispatchQueue.main.async {
                for bookmark in selectedBookmarks {
                    guard let url = try? bookmark.url(location) else {
                        continue
                    }
                    Application.open(url)
                }
            }
        }
    }

    @MainActor public func update(ids: Set<Bookmark.ID>? = nil, toRead: Bool) async {
        let bookmarks = await bookmarks(for: ids)
            .map { $0.setting(toRead: toRead) }
        manager.updateBookmarks(bookmarks, completion: errorHandler())
    }

    @MainActor public func update(ids: Set<Bookmark.ID>? = nil, shared: Bool) async {
        let bookmarks = await bookmarks(for: ids)
            .map { $0.setting(shared: shared) }
        manager.updateBookmarks(bookmarks, completion: errorHandler())
    }

    @MainActor public func delete(ids: Set<Bookmark.ID>? = nil) async {
        let bookmarks = await bookmarks(for: ids)
        manager.deleteBookmarks(bookmarks, completion: errorHandler())
    }

    // TODO: Rethink the threading here.
    @MainActor public func copy(ids: Set<Bookmark.ID>? = nil) async {
        let bookmarks = await bookmarks(for: ids)
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(bookmarks.map { $0.url.absoluteString as NSString })
            NSPasteboard.general.writeObjects(bookmarks.map { $0.url as NSURL })
        }
    }

    // TODO: Rethink the threading here.
    @MainActor public func copyTags(ids: Set<Bookmark.ID>? = nil) async {
        let bookmarks = await bookmarks(for: ids)
        let tags = bookmarks.tags.sorted().joined(separator: " ")
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([tags as NSString])
        }
    }

    // TODO: Consider whether we should pull this down into the manager.
    @MainActor public func addTags(ids: Set<Bookmark.ID>? = nil, tags: Set<String>, markAsRead: Bool) async {
        let bookmarks = await bookmarks(for: ids)
            .map { item in
                item
                    .adding(tags: tags)
                    .setting(toRead: markAsRead ? false : item.toRead)
            }
        manager.updateBookmarks(bookmarks, completion: errorHandler({ _ in }))
    }

    // TODO: Set this asynchronously using combine.
    @MainActor public var selectionContainsUnreadBookmarks: Bool {
        let bookmarks = bookmarks.filter { selection.contains($0.id) }
        return bookmarks.containsUnreadBookmark
    }

    // TODO: Set this asynchronously using combine.
    @MainActor public var selectionContainsPublicBookmark: Bool {
        let bookmarks = bookmarks.filter { selection.contains($0.id) }
        return bookmarks.containsPublicBookmark
    }

    private func errorHandler<T>(_ completion: @escaping (Result<T, Error>) -> Void = { _ in }) -> (Result<T, Error>) -> Void {
        let completion = DispatchQueue.global().asyncClosure(completion)
        return { result in
            if case .failure(let error) = result {
                print("Failed to perform operation with error \(error).")
                DispatchQueue.main.async {
                    self.lastError = error
                }
            }
            completion(result)
        }
    }

}
