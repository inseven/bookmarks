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



extension Item {

    convenience init(row: Row) throws {
        guard let url = URL(string: try row.get(Database.Schema.url)) else {
            throw DatabaseError.invalidUrl
        }
        self.init(identifier: try row.get(Database.Schema.identifier),
                  title: try row.get(Database.Schema.title),
                  url: url,
                  tags: [],
                  date: try row.get(Database.Schema.date))
    }

}

public class Database {

    class Schema {

        static let items = Table("items")

        static let id = Expression<Int64>("id")
        static let identifier = Expression<String>("identifier")
        static let title = Expression<String>("title")
        static let url = Expression<String>("url")
        static let date = Expression<Date>("date")

    }

    var path: URL
    var db: Connection
    var syncQueue = DispatchQueue(label: "Database.syncQueue")
    var observers: [DatabaseObserver] = []  // Synchronized on syncQueue

    // TODO: What's the thread safety of the database? Can we support multiple queues (e.g., for background processing)
    // TODO: Version bumper (see anytime code)  (https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#migrations-and-schema-versioning)
    // TODO: The ID should be self-updating and then we can know which objects we've processed? Or is it better to simply do a join?
    // TODO: Support quick deletion?
    // TODO: Why is it creating the database twice?

    public init(path: URL) throws {
        self.path = path
        self.db = try Connection(path.path)
        try syncQueue.sync {
            print("creating table...")
            try db.run(Schema.items.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.identifier, unique: true)
                t.column(Schema.title)
                t.column(Schema.url, unique: true)
                t.column(Schema.date)
            })
            try db.run(Schema.items.createIndex(Schema.identifier, ifNotExists: true))
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
        let run = try db.prepare(Schema.items.filter(Schema.identifier == identifier).limit(1)).map(Item.init)
        guard let result = run.first else {
            throw DatabaseError.unknown  // Seems wrong?
        }
        return result
    }

    public func item(identifier: String, completion: @escaping (Swift.Result<Item, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result { try self.syncQueue_item(identifier: identifier) }
            completion(result)
        }
    }

    public func insertOrUpdate(_ item: Item, completion: @escaping (Swift.Result<Item, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<Item, Error> {
                try self.db.transaction {
                    // N.B. While it would be possible to use an insert or replace strategy, we want to ensure we only
                    // notify observers if the data has actually changed so we instead fetch the item and compare.
                    if let existingItem = try? self.syncQueue_item(identifier: item.identifier) {
                        if existingItem != item {
                            print("updating \(item)...")
                            try self.db.run(Schema.items.filter(Schema.identifier == item.identifier).update(
                                Schema.title <- item.title,
                                Schema.url <- item.url.absoluteString,
                                Schema.date <- item.date
                            ))
                            self.syncQueue_notifyObservers()
                        } else {
                            print("skipping \(item)...")
                        }
                    } else {
                        print("inserting \(item)...")
                        _ = try self.db.run(Schema.items.insert(
                            Schema.identifier <- item.identifier,
                            Schema.title <- item.title,
                            Schema.url <- item.url.absoluteString,
                            Schema.date <- item.date
                        ))
                        self.syncQueue_notifyObservers()
                    }
                }
                return item
            }
            completion(result)
        }
    }

    public func delete(identifier: String, completion: @escaping (Swift.Result<Int, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                try self.db.run(Schema.items.filter(Schema.identifier == identifier).delete())
            }
            self.syncQueue_notifyObservers()
            completion(result)
        }
    }

    func itemQuery(filter: String? = nil) -> QueryType {
        guard let filter = filter,
              !filter.isEmpty else {
            return Schema.items.order(Schema.date.desc)
        }
        let filters = filter.tokens.map { Schema.title.like("%\($0)%") || Schema.url.like("%s\($0)%") }
        let query = Schema.items.filter(filters.reduce(Expression<Bool>(value: true)) { $0 && $1 })
        return query.order(Schema.date.desc)
    }

    public func items(filter: String? = nil, completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                try self.db.prepare(self.itemQuery(filter: filter)).map(Item.init)
            }
            completion(result)
        }
    }

    public func identifiers(completion: @escaping (Swift.Result<[String], Error>) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))  // TODO: Not necessary??
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                return try self.db.prepare(Schema.items.select(Schema.identifier)).map { row -> String in
                    return try row.get(Schema.identifier)
                }
            }
            completion(result)
        }
    }

}
