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

import SwiftUI

import BookmarksCore

public class BookmarksSelection: ObservableObject {

    enum SheetType {
        case addTags(items: [Item])
    }

    // TODO: Consider renaming sheet to operation?
    @Published var sheet: SheetType? = nil
    @Published var lastError: Error? = nil
    @Published var items: Set<Item> = []

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }
    var containsUnreadBookmark: Bool { items.containsUnreadBookmark }
    var containsPublicBookmark: Bool { items.containsPublicBookmark }

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

    // TODO: These don't need the manager (which should still be renamed to a store.
    public func open(manager: BookmarksManager, location: Item.Location = .web) {
        manager.openItems(items, location: location, completion: errorHandler())
    }

    public func update(manager: BookmarksManager, toRead: Bool) {
        let items = items.map { $0.setting(toRead: toRead) }
        manager.updateItems(items, completion: errorHandler())
    }

    public func update(manager: BookmarksManager, shared: Bool) {
        let items = items.map { $0.setting(shared: shared) }
        manager.updateItems(items, completion: errorHandler())
    }

    public func update(manager: BookmarksManager, items: [Item], completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        manager.updateItems(items, completion: errorHandler(completion))
    }

    public func addTags() {
        sheet = .addTags(items: Array(items))
    }

    public func delete(manager: BookmarksManager) {
        manager.deleteItems(items, completion: errorHandler())
    }

    public func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(items.map { $0.url.absoluteString as NSString })
        NSPasteboard.general.writeObjects(items.map { $0.url as NSURL })
    }

    public func copyTags() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(items.tags.map { $0 as NSString })
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
        case .addTags(let items):
            return "addTags:\(items.map { $0.identifier }.joined(separator: ","))"
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
