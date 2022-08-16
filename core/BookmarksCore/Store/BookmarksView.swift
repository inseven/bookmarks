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

public class BookmarksView: ObservableObject {

    @Environment(\.manager) var manager: BookmarksManager

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
    @Published private var query: AnyQuery

    private let section: BookmarksSection
    private var cancellables: Set<AnyCancellable> = []
    private let queryQueue = DispatchQueue(label: "queryQueue")

    // TODO: Don't inject the query
    public init(section: BookmarksSection) {
        self.section = section
        self.query = section.query
        self.title = section.navigationTitle
    }

    @MainActor private func updateBookmarks() {

        // Query the database whenever a change occurs or the query changes.
        manager.database.$update
            .combineLatest($query)
            .debounce(for: .seconds(0.2), scheduler: queryQueue)
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
    }

    @MainActor private func updateQuery() {

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

    }

    @MainActor private func updateSuggestedTokens() {
        // Update the suggested tokens.
        // TODO: Debounce?
        manager.tagsView.$trie
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
    }

    @MainActor private func updateTitle() {
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
    }

    @MainActor private func updateSubtitle() {
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

    @MainActor public func start() {
        print("(\(Unmanaged.passUnretained(self).toOpaque())) BookmarksView.start()")
        updateBookmarks()
        updateQuery()
        updateSuggestedTokens()
        updateTitle()
        updateSubtitle()
    }

    @MainActor public func stop() {
        print("(\(Unmanaged.passUnretained(self).toOpaque())) BookmarksView.stop()")
        cancellables.removeAll()
        bookmarks = []
        state = .loading
    }

    @MainActor public func bookmarks(for ids: Set<Bookmark.ID>) async -> [Bookmark] {
        let bookmarks = bookmarks
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: bookmarks.filter { ids.contains($0.id) })
            }
        }
    }

    @MainActor public func open(ids: Set<Bookmark.ID>) {
        let bookmarks = bookmarks
        DispatchQueue.global(qos: .userInitiated).async {
            let selectedBookmarks = bookmarks.filter { ids.contains($0.id) }
            DispatchQueue.main.async {
                for bookmark in selectedBookmarks {
                    self.openURL(bookmark.url)
                }
            }
        }
    }

}
