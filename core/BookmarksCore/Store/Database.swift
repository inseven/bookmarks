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
    case unknown  // TODO: Remove this error
    case unknownMigration(version: Int32)
}

public protocol DatabaseObserver {
    func databaseDidUpdate(database: Database)
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

extension Connection {

    public var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue)") }
    }

}

public class Database {

    class Schema {

        static let items = Table("items")
        static let tags = Table("tags")

        static let id = Expression<Int64>("id")
        static let identifier = Expression<String>("identifier")
        static let title = Expression<String>("title")
        static let url = Expression<String>("url")
        static let date = Expression<Date>("date")

        static let name = Expression<String>("name")

    }

    let path: URL
    var syncQueue = DispatchQueue(label: "Database.syncQueue")
    var db: Connection  // Synchronized on syncQueue
    var observers: [DatabaseObserver] = []  // Synchronized on syncQueue

    // TODO: What's the thread safety of the database? Can we support multiple queues (e.g., for background processing)
    // TODO: Use a join against a derived data table to determine if we've fetched the data (this can also include a derivation version?)
    // TODO: Support right-click deletion of rows
    // TODO: Why is it creating the database twice?
    // TODO: Add tags back.
    // TODO: Does much of this really need to be public?

    static func itemQuery(filter: String? = nil) -> QueryType {
        guard let filter = filter,
              !filter.isEmpty else {
            return Schema.items.order(Schema.date.desc)
        }
        let filters = filter.tokens.map { Schema.title.like("%\($0)%") || Schema.url.like("%s\($0)%") }
        let query = Schema.items.filter(filters.reduce(Expression<Bool>(value: true)) { $0 && $1 })
        return query.order(Schema.date.desc)
    }

    public init(path: URL) throws {
        self.path = path
        self.db = try Connection(path.path)
        try syncQueue.sync {
            try self.syncQueue_migrate()
        }
    }

    static var migrations: [Int32:(Connection) throws -> Void] = [
        1: { _ in },
        2: { _ in },
        3: { db in
            print("creating items table...")
            try db.run(Schema.items.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.identifier, unique: true)
                t.column(Schema.title)
                t.column(Schema.url, unique: true)
                t.column(Schema.date)
            })
            try db.run(Schema.items.createIndex(Schema.identifier, ifNotExists: true))
        },
        4: { db in
            print("creating tags table...")
            try db.run(Schema.tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.name, unique: true)
            })
        }
    ]

    static var schemaVersion: Int32 = Array(migrations.keys).max() ?? 0

    func syncQueue_migrate() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try db.transaction {
            let currentVersion = db.userVersion
            print("version \(currentVersion)")
            guard currentVersion < Self.schemaVersion else {
                print("schema up to date")
                return
            }
            for version in currentVersion + 1 ... Self.schemaVersion {
                print("migrating to \(version)...")
                guard let migration = Self.migrations[version] else {
                    throw DatabaseError.unknownMigration(version: version)
                }
                try migration(self.db)
                db.userVersion = version
            }
        }
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

    public func items(filter: String? = nil, completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                try self.db.prepare(Self.itemQuery(filter: filter)).map(Item.init)
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
