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

public class BookmarksView: ObservableObject {

    public enum State {
        case loading
        case ready
    }

    let database: Database

    @Published public var subtitle: String = ""
    @Published public var bookmarks: [Bookmark] = []
    @Published public var state: State = .loading
    @Published public var query: AnyQuery

    private var cancellables: Set<AnyCancellable> = []

    public init(database: Database, query: AnyQuery) {
        self.database = database
        self.query = query
    }

    func update(query: AnyQuery) {
        dispatchPrecondition(condition: .onQueue(.main))
        print("fetching bookmarks...")

        database.bookmarks(query: query) { result in
            DispatchQueue.main.async {
                guard self.query == query else {
                    print("ignoring out-of-date results...")
                    return
                }
                switch result {
                case .success(let bookmarks):
                    print("received \(bookmarks.count) bookmarks")
                    self.bookmarks = bookmarks
                    self.state = .ready
                case .failure(let error):
                    print("Failed to load data with error \(error)")
                }
            }
        }
    }

    @MainActor public func start() {
        dispatchPrecondition(condition: .onQueue(.main))

        // Query the database whenever a change occurs or the query changes.
        DatabasePublisher(database: database)
            .prepend(())
            .combineLatest($query)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _, query in
                self.update(query: query)
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

    @MainActor public func clear() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.bookmarks = []
        self.state = .loading
    }

    @MainActor public func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        cancellables.removeAll()
        self.bookmarks = []
    }

}
