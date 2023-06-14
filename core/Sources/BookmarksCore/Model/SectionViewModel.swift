// Copyright (c) 2020-2023 InSeven Limited
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

public class SectionViewModel: ObservableObject, Runnable {

    public enum State {
        case loading
        case ready
    }

    @Published public var title: String
    @Published public var subtitle: String = ""
    @Published public var bookmarks: [Bookmark] = []
    @Published public var urls: [URL] = []
    @Published public var state: State = .loading
    @Published public var filter: String = ""
    @Published public var tokens: [String] = []
    @Published public var suggestedTokens: [String] = []
    @Published public var layoutMode: LayoutMode
    @Published public var selection: Set<Bookmark.ID> = []
    @Published public var previewURL: URL? = nil

    @MainActor @Published public var lastError: Error? = nil

    @Published private var query: AnyQuery
    @Published private var bookmarksLookup: [Bookmark.ID: Bookmark] = [:]

    private let applicationModel: ApplicationModel?
    private let sceneModel: SceneModel?
    private let section: BookmarksSection
    private var cancellables: Set<AnyCancellable> = []

    public var isPlaceholder: Bool {
        return applicationModel == nil
    }

    public init(applicationModel: ApplicationModel? = nil,
                sceneModel: SceneModel? = nil,
                section: BookmarksSection = .all) {
        self.applicationModel = applicationModel
        self.sceneModel = sceneModel
        self.section = section
        self.query = section.query
        self.title = section.navigationTitle
        self.layoutMode = applicationModel?.settings.layoutMode(for: section) ?? .grid
    }

    @MainActor public func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let applicationModel else {
            return
        }

        // Set up the initial state (in case we are being reused).
        bookmarks = []
        state = .loading

        // Query the database whenever a change occurs or the query changes.
        applicationModel.database
            .updatePublisher
            .combineLatest($query)
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.global())
            .asyncMap { (_, query) in
                do {
                    let bookmarks = try await applicationModel.database.bookmarks(query: query)
                    let bookmarksLookup = bookmarks.reduce(into: [Bookmark.ID: Bookmark]()) { $0[$1.id] = $1 }
                    let urls = bookmarks.map { $0.url }
                    return (query, bookmarks, bookmarksLookup, urls)
                } catch {
                    return (query, [], [:], [])
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { query, bookmarks, bookmarksLookup, urls in
                // Guard against updating the bookmarks with results from an old query.
                guard self.query == query else {
                    print("Discarding query")
                    return
                }
                self.bookmarks = bookmarks
                self.bookmarksLookup = bookmarksLookup
                self.urls = urls
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
        applicationModel.tagsModel.$trie
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

        // Save the layout mode.
        $layoutMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] layoutMode in
                guard let self else { return }
                applicationModel.settings.setLayoutMode(layoutMode, for: section)
            }
            .store(in: &cancellables)

        // Update the selection if the preview URL changes.
        $previewURL
            .compactMap { $0 }
            .debounce(for: 0.2, scheduler: DispatchQueue.global(qos: .userInteractive))
            .combineLatest($bookmarks)
            .compactMap { url, bookmarks in
                bookmarks.first { $0.url == url }?.id
            }
            .map { Set([$0]) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.selection, on: self)
            .store(in: &cancellables)

    }

    @MainActor public func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        cancellables.removeAll()
        self.bookmarks = []
    }

    @MainActor public func bookmarks(for ids: Set<Bookmark.ID>? = nil) -> [Bookmark] {
        let ids = ids ?? self.selection
        return ids.compactMap { bookmarksLookup[$0] }
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
                    self.sceneModel?.showURL(url)
                }
            }
        }
    }

    @MainActor public func urls(ids: Set<Bookmark.ID>? = nil) -> [URL] {
        let bookmarks = bookmarks(for: ids)
        return bookmarks.map { $0.url }
    }

    // TODO: Make this async?
    @MainActor public func update(ids: Set<Bookmark.ID>? = nil, toRead: Bool) {
        guard let applicationModel else {
            return
        }
        let bookmarks = bookmarks(for: ids)
            .map { $0.setting(toRead: toRead) }
        Task {
            do {
                try await applicationModel.update(bookmarks: bookmarks)
            } catch {
                self.lastError = error
            }
        }
    }

    @MainActor public func update(ids: Set<Bookmark.ID>? = nil, shared: Bool) async {
        guard let applicationModel else {
            return
        }
        let bookmarks = bookmarks(for: ids)
            .map { $0.setting(shared: shared) }
        do {
            try await applicationModel.update(bookmarks: bookmarks)
        } catch {
            self.lastError = error
        }
    }

    @MainActor public func delete(ids: Set<Bookmark.ID>? = nil) async {
        guard let applicationModel else {
            return
        }
        let bookmarks = bookmarks(for: ids)
        do {
            try await applicationModel.delete(bookmarks: bookmarks)
        } catch {
            self.lastError = error
        }
    }

    @MainActor public func copy(ids: Set<Bookmark.ID>? = nil) {
        let bookmarks = bookmarks(for: ids)
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(bookmarks.map { $0.url.absoluteString as NSString })
        NSPasteboard.general.writeObjects(bookmarks.map { $0.url as NSURL })
#else
        UIPasteboard.general.urls = bookmarks.map { $0.url }
#endif
    }

    @MainActor public func copyTags(ids: Set<Bookmark.ID>? = nil) {
        let bookmarks = bookmarks(for: ids)
        let tags = bookmarks.tags.sorted().joined(separator: " ")
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([tags as NSString])
#else
        UIPasteboard.general.string = tags
#endif
    }

    @MainActor public func showPreview() {
        let bookmarks = bookmarks()
        previewURL = bookmarks.first?.url
    }

    // TODO: Set this asynchronously using combine.
    @MainActor public var selectionTags: Set<String> {
        let bookmarks = bookmarks.filter { selection.contains($0.id) }
        return Set(bookmarks.map { $0.tags }.reduce([], +))
    }

    @MainActor @MenuItemBuilder public func contextMenu(_ selection: Set<Bookmark.ID>,
                                                        openWindow: OpenWindowAction? = nil) -> [MenuItem] {

        let bookmarks = bookmarks(for: selection)
        let containsUnreadBookmark = bookmarks.containsUnreadBookmark
        let containsPublicBookmark = bookmarks.containsPublicBookmark

        MenuItem("Open", systemImage: "safari") {
            self.open(ids: selection)
        }
        MenuItem("Open on Internet Archive", systemImage: "clock") {
            self.open(ids: selection, location: .internetArchive)
        }
        Divider()
#if os(iOS)
        if bookmarks.count == 1, let bookmark = bookmarks.first {
            MenuItem("Get Info", systemImage: "square.and.pencil") {
                self.sceneModel?.edit(bookmark)
            }
        }
#else
        MenuItem("Get Info", systemImage: "square.and.pencil") {
            for id in selection {
                openWindow?(value: id)
            }
        }
#endif
        Divider()
        MenuItem(containsUnreadBookmark ? "Mark as Read" : "Mark as Unread",
                 systemImage: containsUnreadBookmark ? "circle" : "circle.inset.filled") {
            self.update(ids: selection, toRead: !containsUnreadBookmark)
        }
        MenuItem(containsPublicBookmark ? "Make Private" : "Make Public",
                 systemImage: containsPublicBookmark ? "lock": "globe") {
            await self.update(ids: selection, shared: !containsPublicBookmark)
        }
        Divider()
        MenuItem("Copy", systemImage: "doc.on.doc") {
            self.copy(ids: selection)
        }
        MenuItem("Copy Tags", systemImage: "doc.on.doc") {
            self.copyTags(ids: selection)
        }
        Divider()
        MenuItem("Delete", systemImage: "trash", role: .destructive) {
            await self.delete(ids: selection)
        }
    }

}
