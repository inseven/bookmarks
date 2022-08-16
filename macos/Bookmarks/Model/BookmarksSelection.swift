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

import SwiftUI

import BookmarksCore

public class BookmarksSelection: ObservableObject {

    enum SheetType {
        case addTags(bookmarks: [Bookmark])
    }

    @Published var sheet: SheetType? = nil
    @Published var lastError: Error? = nil
    @Published var bookmarks: Set<Bookmark> = []  // TODO: Remove this?
    @Published var selection: Set<Bookmark.ID> = []

    var count: Int { bookmarks.count }
    var isEmpty: Bool { bookmarks.isEmpty }
    var containsUnreadBookmark: Bool { bookmarks.containsUnreadBookmark }
    var containsPublicBookmark: Bool { bookmarks.containsPublicBookmark }

    public init() {}

    public func errorHandler<T>(_ completion: @escaping (Result<T, Error>) -> Void = { _ in }) -> (Result<T, Error>) -> Void {
        let completion = DispatchQueue.global().asyncClosure(completion)
        return { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    self.lastError = error
                }
            }
            completion(result)
        }
    }

    @MainActor public func open(manager: BookmarksManager, location: Bookmark.Location = .web) {
        manager.open(bookmarks, location: location)
    }

    public func update(manager: BookmarksManager, toRead: Bool) {
        let bookmarks = bookmarks.map { $0.setting(toRead: toRead) }
        manager.updateBookmarks(bookmarks, completion: errorHandler())
    }

    public func update(manager: BookmarksManager, shared: Bool) {
        let bookmarks = bookmarks.map { $0.setting(shared: shared) }
        manager.updateBookmarks(bookmarks, completion: errorHandler())
    }

    public func update(manager: BookmarksManager,
                       bookmarks: [Bookmark],
                       completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        manager.updateBookmarks(bookmarks, completion: errorHandler(completion))
    }

    public func addTags() {
        sheet = .addTags(bookmarks: Array(bookmarks))
    }

    public func delete(manager: BookmarksManager) {
        manager.deleteBookmarks(bookmarks, completion: errorHandler())
    }

    public func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(bookmarks.map { $0.url.absoluteString as NSString })
        NSPasteboard.general.writeObjects(bookmarks.map { $0.url as NSURL })
    }

    public func copyTags() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(bookmarks.tags.map { $0 as NSString })
    }

    public func showError(error: Error) {
        DispatchQueue.main.async {
            self.lastError = error
        }
    }

}

extension BookmarksSelection.SheetType: Identifiable {

    var id: String {
        switch self {
        case .addTags(let bookmarks):
            return "addTags:\(bookmarks.map { $0.identifier }.joined(separator: ","))"
        }
    }

}

public struct SelectionEnvironmentKey: EnvironmentKey {

    public static var defaultValue = BookmarksSelection()

}

public extension EnvironmentValues {

    var selection: BookmarksSelection {
        get { self[SelectionEnvironmentKey.self] }
        set { self[SelectionEnvironmentKey.self] = newValue }
    }

}

extension BookmarksSelection: Countable {

}
