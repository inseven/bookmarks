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

public protocol DatabaseObserver {
    var id: UUID { get }
    func databaseDidUpdate(database: Database)
}

extension String {

    func wrap<T>(_ expression: Expressible) -> Expression<T> {
        return Expression("\(self)(\(expression.expression.template))", expression.expression.bindings)
    }

}

extension Item {

    convenience init(row: Row) throws {
        let urlString = try row.get(Database.Schema.url)
        let url = try urlString.asUrl()
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

//public struct Tag: Hashable {
//
//    let id: Int64
//    let name: String
//
//    init(id: Int64, name: String) {
//        self.id = id
//        self.name = name
//    }
//
//    init(row: Row) throws {
//        self.init(id: try row.get(Database.Schema.tags[Database.Schema.id]),
//                  name: try row.get(Database.Schema.name))
//    }
//
//}

extension ExpressionType where UnderlyingType : Value, UnderlyingType.Datatype : Comparable {

    public var groupConcat: Expression<UnderlyingType?> {
        return "group_concat".wrap(self)
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
        },
        7: { db in
            print("recreate the tags table ignoring case")
            try db.run(Schema.items_to_tags.delete())
            try db.run(Schema.tags.drop())
            try db.run(Schema.tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.name, unique: true, collate: .nocase)
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

    public func remove(observer: DatabaseObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.removeAll { observer.id == $0.id }
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
                    throw BookmarksError.unknownMigration(version: version)
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
        let run = try db.prepare(Schema.items.filter(Schema.identifier == identifier).limit(1)).map(Item.init)
        guard let result = run.first else {
            throw BookmarksError.itemNotFound(identifier: identifier)
        }
        let tags = try syncQueue_tags(itemIdentifier: identifier)
        return Item(identifier: result.identifier,
                    title: result.title,
                    url: result.url,
                    tags: Set(tags),
                    date: result.date)
    }

    func syncQueue_fetchOrInsertTag(name: String) throws -> Int64 {
        if let id = try? syncQueue_tag(name: name) {
            return id
        }
        let id = try db.run(Schema.tags.insert(
            Schema.name <- name
        ))
        return id
    }

    func syncQueue_tag(name: String) throws -> Int64 {
        let results = try db.prepare(Schema.tags.filter(Schema.name == name).limit(1)).map { row in
            try row.get(Schema.id)
        }
        guard let result = results.first else {
            throw BookmarksError.tagNotFound(name: name)
        }
        return result
    }

    func syncQueue_tags(itemIdentifier: String) throws -> Set<String> {
        Set(try self.db.prepare(Schema.items_to_tags
                                    .join(Schema.items, on: Schema.items_to_tags[Schema.item_id] == Schema.items[Schema.id])
                                    .join(Schema.tags, on: Schema.items_to_tags[Schema.tag_id] == Schema.tags[Schema.id])
                                    .filter(Schema.identifier == itemIdentifier))
                .map { row -> String in
                    try row.get(Schema.tags[Schema.name])
                })
    }

    public func tags(completion: @escaping (Swift.Result<Set<String>, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let lowercaseName = Schema.name.lowercaseString
            let result = Swift.Result {
                Set(try self.db.prepare(Schema.tags.select(lowercaseName)).map { row in
                    try row.get(lowercaseName)
                })
            }
            completion(result)
        }
    }

    public func item(identifier: String, completion: @escaping (Swift.Result<Item, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { try self.syncQueue_item(identifier: identifier) }
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    func syncQueue_insertOrReplace(item: Item) throws {
        let tags = try item.tags.map { try syncQueue_fetchOrInsertTag(name: $0) }
        let itemId = try self.db.run(
            Schema.items.insert(or: .replace,
                                Schema.identifier <- item.identifier,
                                Schema.title <- item.title,
                                Schema.url <- item.url.absoluteString,
                                Schema.date <- item.date
            ))
        for tag_id in tags {
            _ = try self.db.run(
                Schema.items_to_tags.insert(or: .replace,
                                            Schema.item_id <- itemId,
                                            Schema.tag_id <- tag_id))
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

    public func syncQueue_items(filter: String? = nil, tags: [String]? = nil) throws -> [Item] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        var filterExpression: Expression = Expression<Bool?>(value: true)
        if let filter = filter {
            let filters = filter.tokens.map {
                Schema.title.like("%\($0)%") || Schema.url.like("%\($0)%") || Schema.name.like("%\($0)%")
            }
            filterExpression = filters.reduce(Expression(value: true)) { $0 && $1 }
        }

        if let tags = tags {
            if tags.isEmpty {
                let optionalName = Expression<String?>("name")
                filterExpression = filterExpression && optionalName == nil
            } else {
                let tagExpression = tags.map { Schema.name.lowercaseString == $0.lowercased() }.reduce(Expression(value: true)) { $0 && $1 }
                filterExpression = filterExpression && tagExpression
            }
        }

        let tagsColumn = Schema.name.groupConcat
        let select =
            Schema.items
            .join(.leftOuter,
                  Schema.items_to_tags,
                  on: Schema.items[Schema.id] == Schema.items_to_tags[Schema.item_id])
            .join(.leftOuter,
                  Schema.tags,
                  on: Schema.items_to_tags[Schema.tag_id] == Schema.tags[Schema.id])
            .group(Schema.identifier)
            .select(
                Schema.identifier,
                Schema.title,
                Schema.url,
                tagsColumn.lowercaseString,
                Schema.date)
            .filter(filterExpression)
            .order(Schema.date.desc)

        let items = try db.prepare(select).map { row -> Item in
            let tags = try? row.get(tagsColumn)
            let safeTags = tags?.components(separatedBy: ",") ?? []
            return Item(identifier: try row.get(Schema.identifier),
                        title: try row.get(Schema.title),
                        url: try row.get(Schema.url).asUrl(),
                        tags: Set(safeTags),
                        date: try row.get(Schema.date))
        }
        return items
    }

    public func items(filter: String? = nil, tags: [String]? = nil, completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<[Item], Error> {
                try self.syncQueue_items(filter: filter, tags: tags)
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
