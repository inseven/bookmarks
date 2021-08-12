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

    @Published var sheet: SheetType? = nil
    @Published var isEmpty: Bool = true
    @Published var lastError: Error? = nil

    var items: Set<Item> = [] {
        didSet {
            // We play this little trick with `isEmpty` to ensure that the application, which necessarily owns the
            // selection (as-of SwiftUI 2) doesn't perform a full re-render whenever the selection changes, only when
            // the menu state needs to change (which is almost certainly gated on whether the selection is empty.
            guard isEmpty != items.isEmpty else {
                return
            }
            isEmpty = items.isEmpty
        }
    }
    var count: Int { items.count }

    public init() {

    }

    public func errorHandler<T>() -> (Result<T, Error>) -> Void {
        return { result in
            guard case .failure(let error) = result else {
                return
            }
            DispatchQueue.main.async {
                self.lastError = error
            }
        }
    }

    // TODO: Enum for the open type?
    public func open(manager: BookmarksManager) {
        manager.open(items: Array(items), completion: errorHandler())
    }

    public func openOnInternetArchive(manager: BookmarksManager) {
        manager.openOnInternetArchive(items: Array(items), completion: errorHandler())
    }

    public func addTags() {
        sheet = .addTags(items: Array(items))
    }

    public func delete(manager: BookmarksManager) {
        manager.deleteItems(items, completion: errorHandler())
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
