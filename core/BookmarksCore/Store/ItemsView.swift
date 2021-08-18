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
import Foundation

public class ItemsView: ObservableObject {

    public enum State {
        case loading
        case ready
    }

    let database: Database
    var updateCancellable: AnyCancellable? = nil
    var searchCancellable: AnyCancellable? = nil

    @Published public var query: AnyQuery
    @Published public var items: [Bookmark] = []
    @Published public var state: State = .loading

    public init(database: Database, query: AnyQuery) {
        self.database = database
        self.query = query
    }

    func update() {
        dispatchPrecondition(condition: .onQueue(.main))
        print("fetching items...")

        let activeQuery = self.query
        database.items(query: activeQuery) { result in
            DispatchQueue.main.async {
                guard self.query == activeQuery else {
                    print("ignoring out-of-date results...")
                    return
                }
                switch result {
                case .success(let items):
                    print("received \(items.count) items")
                    self.items = items
                    self.state = .ready
                case .failure(let error):
                    print("Failed to load data with error \(error)")
                }
            }
        }
    }

    public func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        print("start observing...")
        self.updateCancellable = DatabasePublisher(database: database).debounce(for: .seconds(1), scheduler: DispatchQueue.main).sink { _ in
            self.update()
        }
        self.searchCancellable = $query.receive(on: DispatchQueue.main).sink { query in
            print("searching for '\(query.filter)'...")
            self.update()
        }
        self.update()
    }

    public func clear() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.items = []
        self.state = .loading
    }

    public func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        print("stop observing...")
        self.updateCancellable?.cancel()
        self.updateCancellable = nil
        self.searchCancellable?.cancel()
        self.searchCancellable = nil
        self.items = []
    }

}
