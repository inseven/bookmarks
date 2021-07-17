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

public struct Tag: Hashable {

    let id: Int64
    let name: String

    init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }

    init(row: Row) throws {
        self.init(id: try row.get(Database.Schema.tags[Database.Schema.id]),
                  name: try row.get(Database.Schema.name))
    }

}

public class Database {

    class Schema {

        static let items = Table("items")
        static let tags = Table("tags")
        static let items_to_tags = Table("items_to_tags")

        static let id = Expression<Int64>("id")
        static let identifier = Expression<String>("identifier")
        static let title = Expression<String>("title")
        static let url = Expression<String>("url")
        static let date = Expression<Date>("date")
        static let name = Expression<String>("name")
        static let item_id = Expression<Int64>("item_id")
        static let tag_id = Expression<Int64>("tag_id")

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
        },
        5: { db in
            print("creating items_to_tags table...")
            try db.run(Schema.items_to_tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.item_id)
                t.column(Schema.tag_id)
                t.unique(Schema.item_id, Schema.tag_id)
            })
        },
        6: { db in
            print("adding foreign key constraints to items_t_tags table...")
            try db.run(Schema.items_to_tags.drop())
            try db.run(Schema.items_to_tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.item_id)
                t.column(Schema.tag_id)
                t.unique(Schema.item_id, Schema.tag_id)
                t.foreignKey(Schema.item_id, references: Schema.items, Schema.id, delete: .cascade)
                t.foreignKey(Schema.tag_id, references: Schema.tags, Schema.id, delete: .cascade)
            })
        }
    ]

    static var schemaVersion: Int32 = Array(migrations.keys).max() ?? 0

    let path: URL
    var syncQueue = DispatchQueue(label: "Database.syncQueue")
    var db: Connection  // Synchronized on syncQueue
    var observers: [DatabaseObserver] = []  // Synchronized on syncQueue

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

    public func add(observer: DatabaseObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.append(observer)
        }
    }

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
        // TODO: TRANSACTION?
        let run = try db.prepare(Schema.items.filter(Schema.identifier == identifier).limit(1)).map(Item.init)
        guard let result = run.first else {
            throw DatabaseError.unknown  // TODO: Seems wrong?
        }
        let tags = try syncQueue_tags(itemIdentifier: identifier)
        return Item(identifier: result.identifier,
                    title: result.title,
                    url: result.url,
                    tags: Set(tags.map { $0.name }),
                    date: result.date)
    }

    // TODO: Make sure all this is actually correctly done in a transaction.

    // TODO: Rename this to ensure existing or similar?
    func syncQueue_insertOrReplaceTag(name: String) throws -> Tag {
        if let tag = try? syncQueue_tag(name: name) {
            return tag
        }
        let id = try db.run(Schema.tags.insert(
            Schema.name <- name
        ))
        return Tag(id: id, name: name)
    }

    func syncQueue_tag(name: String) throws -> Tag {
        let results = try db.prepare(Schema.tags.filter(Schema.name == name).limit(1)).map { row in
            Tag(id: try row.get(Schema.id),
                name: try row.get(Schema.name))
        }
        guard let result = results.first else {
            throw DatabaseError.unknown  // TODO: Rename
        }
        return result
    }

    func syncQueue_tags(itemIdentifier: String) throws -> Set<Tag> {
        Set(try self.db.prepare(Schema.items_to_tags
                                    .join(Schema.items, on: Schema.items_to_tags[Schema.item_id] == Schema.items[Schema.id])
                                    .join(Schema.tags, on: Schema.items_to_tags[Schema.tag_id] == Schema.tags[Schema.id])
                                    .filter(Schema.identifier == itemIdentifier))
                .map(Tag.init))
    }

    public func tags(completion: @escaping (Swift.Result<Set<Tag>, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                Set(try self.db.prepare(Schema.tags).map { row in
                    Tag(id: try row.get(Schema.id),
                        name: try row.get(Schema.name))
                })
            }
            completion(result)
        }
    }

    public func item(identifier: String, completion: @escaping (Swift.Result<Item, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result { try self.syncQueue_item(identifier: identifier) }
            completion(result)
        }
    }

    // TODO: What's wrong with the indentation
    func syncQueue_insertOrReplace(item: Item) throws {
        // TODO: Transaction? Probably
        //       Can we assert that we're in a transaction?
        let tags = try item.tags.map { try syncQueue_insertOrReplaceTag(name: $0) }
        let itemId = try self.db.run(Schema.items.insert(or: .replace,
            Schema.identifier <- item.identifier,
            Schema.title <- item.title,
            Schema.url <- item.url.absoluteString,
            Schema.date <- item.date
        ))
        for tag in tags {
            _ = try self.db.run(Schema.items_to_tags.insert(or: .replace,
                Schema.item_id <- itemId,
                Schema.tag_id <- tag.id))
        }
    }

    public func insertOrUpdate(_ item: Item, completion: @escaping (Swift.Result<Item, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<Item, Error> {
                try self.db.transaction {
                    // N.B. While it would be possible to use an insert or replace strategy directly, we want to ensure
                    // we only notify observers if the data has actually changed so we instead fetch the item and
                    // compare.
                    if let existingItem = try? self.syncQueue_item(identifier: item.identifier) {
                        if existingItem != item {
                            print("updating \(item)...")
                            print("existing tags \(existingItem.tags)")
                            print("item tags \(item.tags)")
                            try self.syncQueue_insertOrReplace(item: item)
                            self.syncQueue_notifyObservers()
                        }
                    } else {
                        print("inserting \(item)...")
                        try self.syncQueue_insertOrReplace(item: item)
                        self.syncQueue_notifyObservers()
                    }
                }
                return item
            }
            completion(result)
        }
    }

    // TODO: Clean up database tags when the last item is removed #141
    //       https://github.com/inseven/bookmarks/issues/141
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

    public func rawItems(filter: String? = nil) throws -> [Item] {

        var query = """
            SELECT
                items.identifier,
                title,
                url,
                tags,
                date
            FROM
                items
            LEFT JOIN
                (
                    SELECT
                        item_id,
                        GROUP_CONCAT(tags.name) AS tags
                    FROM
                        items_to_tags
                    INNER JOIN
                        tags
                    ON
                        tags.id == items_to_tags.tag_id
                    GROUP BY
                        item_id
                ) a
            ON
                items.id == item_id
        """

        if let filter = filter {
            let tags = Expression<String>("tags")
            let filters = filter.tokens.map {
                Schema.title.like("%\($0)%") || Schema.url.like("%\($0)%") || tags.like("%\($0)%")
            }
            let compoundFilter = filters.reduce(Expression<Bool>(value: true)) { $0 && $1 }
            query = query + " WHERE " + compoundFilter.asSQL()
        }

        query = query + " ORDER BY date DESC"

        let stmt = try db.prepare(query)
        var items: [Item] = []
        for row in stmt {
            guard let identifier = row[0] as? String,
                  let title = row[1] as? String,
                  let urlString = row[2] as? String,
                  let url = URL(string: urlString),
                  let tags = row[3] as? String?,
                  let date = row[4] as? String else {
                throw DatabaseError.unknown  // TODO Invalid results?
            }
            let safeTags = tags?.components(separatedBy: ",") ?? []
            let item = Item(identifier: identifier,
                            title: title,
                            url: url,
                            tags: Set(safeTags),
                            date: Date.fromDatatypeValue(date))
            items.append(item)
        }

        return items
    }

    public func items(filter: String? = nil, completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<[Item], Error> {
                try self.rawItems(filter: filter)
            }
            completion(result)
        }
    }

    public func identifiers(completion: @escaping (Swift.Result<[String], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                try self.db.prepare(Schema.items.select(Schema.identifier)).map { row -> String in
                    try row.get(Schema.identifier)
                }
            }
            completion(result)
        }
    }

}
