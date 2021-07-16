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

import Foundation
import SwiftUI

import SQLite
import Interact

//public let identifier: String
//public let title: String
//public let url: URL
//public let tags: [String]
//public let date: Date
//public let thumbnail: Image?

// TODO: Can I make an extension to handle URLs?

enum DatabaseError: Error {
    case invalidUrl
    case unknown
}


public protocol DatabaseObserver {

    func databaseDidUpdate(database: Database)

}

// TODO: Does much of this really need to be public?


public class DatabaseStore: ObservableObject, DatabaseObserver {

    var database: Database
    public var filter: String = "" {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            print(filter)
            self.objectWillChange.send() // TODO: Why doesn't this work?
            self.databaseDidUpdate(database: self.database)
        }
    }

    public init(database: Database) {
        self.database = database
        self.database.add(observer: self)
        self.databaseDidUpdate(database: self.database)
    }

    public func databaseDidUpdate(database: Database) {
        // TODO: Consider whether it would be better to convert this to a publisher and debounce it?
        // YES THIS SHOULD DEFINITELY DEBOUNCE UPDATES
        // TODO: Add the tags to support filter by tag.
        DispatchQueue.main.async {
            // TODO: This method shouldn't fail.
            print("requery...")
            database.items(filter: self.filter) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let items):
                        self.items = items
                        self.objectWillChange.send()
                    case .failure(let error):
                        print("Failed to load data with error \(error)")
                    }
                }
            }
        }
    }

    // TODO: This isn't going to perform well.
    public var items: [Item] = []

//    // TODO: State?
//    public var filter: String? {
//        didSet {
//            self.objectWillChange.send()
//        }
//    }

    // TODO: Do the filtering in the database.

}

// TODO: Why is it creating the database twice?


extension Item {

//    var items = Table("items")
//    let id = Expression<Int64>("id")
//    let identifier = Expression<String>("identifier")  // TODO: Remote identifier
//    let title = Expression<String>("title")
//    let url = Expression<String>("url")
//    let date = Expression<Date>("date")

    convenience init(row: Row) throws {
        guard let url = URL(string: try row.get(Database.url)) else {
            throw DatabaseError.invalidUrl
        }
        self.init(identifier: try row.get(Database.identifier),
                  title: try row.get(Database.title),
                  url: url,
                  tags: [],
                  date: try row.get(Database.date))
    }

}

public class Database {

    // TODO: What's the thread safety of this?

    var path: URL
    var db: Connection
    var syncQueue = DispatchQueue(label: "Database.syncQueue")
    var observers: [DatabaseObserver] = []  // Synchronized on syncQueue

    // TODO: Consider namespacing these to make it clearer what they are?
    var items = Table("items")
    let id = Expression<Int64>("id")
    static let identifier = Expression<String>("identifier")  // TODO: Remote identifier
    static let title = Expression<String>("title")
    static let url = Expression<String>("url")
    static let date = Expression<Date>("date")

    // TODO: Version bumper (see anytime code)  (https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#migrations-and-schema-versioning)
    // TODO: The ID should be self-updating and then we can know which objects we've processed? Or is it better to simply do a join?
    // TODO: Support quick deletion?

    public init(path: URL) throws {
        self.path = path
        self.db = try Connection(path.path)
        try syncQueue.sync {
            print("creating table...")
            try db.run(items.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true) // TODO: Autoincrement?
                t.column(Self.identifier, unique: true) // TODO: This probably isn't unique across multiple services.
                t.column(Self.title)
                t.column(Self.url, unique: true)  // TODO: Multiple services could have this?
                t.column(Self.date)
            })
            try db.run(items.createIndex(Self.identifier, ifNotExists: true))
        }
        // TODO: Separate create table affair?
    }

    public func add(observer: DatabaseObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.append(observer)
        }
    }

    func syncQueue_notifyObservers() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let observers = self.observers
        DispatchQueue.global(qos: .background).async {
            for observer in observers {
                observer.databaseDidUpdate(database: self)
            }
        }
    }

    func syncQueue_item(identifier: String) throws -> Item {
        let run = try db.prepare(items.filter(Self.identifier == identifier).limit(1)).map(Item.init)
        guard let result = run.first else {
            throw DatabaseError.unknown  // Seems wrong?
        }
        return result
    }

    // TODO: Non-blocking and chain the completions?
    public func insertOrUpdate(_ item: Item) throws -> Item {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        try syncQueue.sync {
            try db.transaction {
                print("insert or update \(item)...")
                // TODO: Try getting it and don't do anything if it's the same (or update the last updated date if we have one?)
                if let existingItem = try? syncQueue_item(identifier: item.identifier) {
                    if existingItem != item {
                        print("existing item \(existingItem)")
                        print("updating...")
                        try db.run(items.filter(Self.identifier == item.identifier).update(
                            Self.title <- item.title,
                            Self.url <- item.url.absoluteString,
                            Self.date <- item.date
                        ))
                        syncQueue_notifyObservers()
                    } else {
                        print("skipping existing item...")
                    }
                    // TODO: Maybe this is better?
//                    try db.run(users.insert(or: .replace, email <- "alice@mac.com", name <- "Alice B."))
                } else {
                    print("inserting...")
                    let rowId = try db.run(items.insert(
                        Self.identifier <- item.identifier,
                        Self.title <- item.title,
                        Self.url <- item.url.absoluteString,
                        Self.date <- item.date
                    ))
                    print("rowId = \(rowId)")
                    syncQueue_notifyObservers()
                }
            }
            // TODO: Don't do this all the time (check to see if the item has _actually_ changed)
        }
        return item
        // TODO: What do I do about the row ID? Some binding thing? return some new stored object?
    }

    public func itemQuery(filter: String? = nil) -> QueryType {
        guard let filter = filter,
              !filter.isEmpty else {
            return self.items.order(Self.date.desc)
        }
        let filters = filter.tokens.map { Self.title.like("%\($0)%") || Self.url.like("%s\($0)%") }
        let query = self.items.filter(filters.reduce(Expression<Bool>(value: true)) { $0 && $1 })
        return query.order(Self.date.desc)
    }

    public func items(filter: String? = nil, completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))

        // TODO: Is there a trivial way to get a completion on a block?
        // TODO: Consider proxying the dispatch QoS
        let completion: (Swift.Result<[Item], Error>) -> Void = { result in
            DispatchQueue.global(qos: .userInitiated).async {
                completion(result)
            }
        }

        syncQueue.sync {
            let result = Swift.Result {
                return try db.prepare(itemQuery(filter: filter)).map { row -> Item in
                    guard let url = URL(string: try row.get(Self.url)) else {
                        throw DatabaseError.invalidUrl
                    }
                    return Item(identifier: try row.get(Self.identifier),
                                title: try row.get(Self.title),
                                url: url,
                                tags: [],
                                date: try row.get(Self.date))
                }
            }
            completion(result)
        }
    }

}
