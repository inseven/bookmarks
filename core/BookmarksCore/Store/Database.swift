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


public protocol QueryDescription {

    var sql: String { get }

}

public struct Untagged: QueryDescription {

    public var sql: String { "items.id NOT IN (SELECT item_id FROM items_to_tags)" }

    public init() { }

}

public struct HasTag: QueryDescription {

    let name: String

    public var sql: String {
        let tagsFilter = Database.Schema.name.lowercaseString == name.lowercased()
        let tagSubselect = """
            SELECT
                item_id
            FROM
                items_to_tags
            JOIN
                tags
            ON
                items_to_tags.tag_id = tags.id
            WHERE
                \(tagsFilter.asSQL())
            """
        return "items.id IN (\(tagSubselect))"
    }

    public init(_ name: String) {
        self.name = name
    }

}

public struct Contains: QueryDescription {

    let filter: String

    public var sql: String {
        let tagsColumn = Expression<String>("tags")
        let expression = Database.Schema.title.like("%\(filter)%") || Database.Schema.url.like("%\(filter)%") || tagsColumn.like("%\(filter)%")
        return expression.asSQL()
    }

    init(_ filter: String) {
        self.filter = filter
    }

}

public struct MatchesFilter: QueryDescription {

    let filter: String

    public var sql: String {
        let tagsColumn = Expression<String>("tags")
        let filters = filter.tokens.map {
            Database.Schema.title.like("%\($0)%") || Database.Schema.url.like("%\($0)%") || tagsColumn.like("%\($0)%")
        }
        return filters.reduce(Expression(value: true)) { $0 && $1 }.asSQL()
    }

    init(_ filter: String) {
        self.filter = filter
    }

}

public struct And: QueryDescription {

    let lhs: QueryDescription
    let rhs: QueryDescription

    public var sql: String { "(\(lhs.sql)) AND (\(rhs.sql))" }

    init(_ lhs: QueryDescription, _ rhs: QueryDescription) {
        self.lhs = lhs
        self.rhs = rhs
    }

}

// TODO: Why doesn't this work?
//extension QueryDescription {
//
//    static func &&(lhs: QueryDescription, rhs: QueryDescription) -> QueryDescription {
//        return And(lhs, rhs)
//    }
//
//}

public struct True: QueryDescription {

    public var sql: String { "1" }

    public init() { }

}

public class Search: QueryDescription {

    var search: String

    public var sql: String {
        var query: QueryDescription = True()
        let tagPrefix = "tag:"
        for token in search.tokens {
            if token.hasPrefix(tagPrefix) {
                let tag = String(token.dropFirst(tagPrefix.count))
                query = And(query, HasTag(tag))
            } else {
                query = And(query, Contains(token))
            }
        }
        return query.sql
    }

    init(_ search: String) {
        self.search = search
    }

}

public class Today: QueryDescription {

    public var sql: String {
        "date >= datetime('now', '-1 day')"
    }

    public init() { }

}

extension Item {

    convenience init(row: Row) throws {
        self.init(identifier: try row.get(Database.Schema.identifier),
                  title: try row.get(Database.Schema.title),
                  url: try row.get(Database.Schema.url).asUrl(),
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

extension Statement.Element {

    func string(_ index: Int) throws -> String {
        guard let value = self[index] as? String else {
            throw BookmarksError.corrupt
        }
        return value
    }

    func url(_ index: Int) throws -> URL {
        try string(index).asUrl()
    }

    func set(_ index: Int) throws -> Set<String> {
        guard let value = self[index] as? String? else {
            throw BookmarksError.corrupt
        }
        guard let safeValue = value else {
            return Set()
        }
        return Set(safeValue.components(separatedBy: ","))
    }

    func date(_ index: Int) throws -> Date {
        Date.fromDatatypeValue(try string(index))
    }

}

extension String {

    func and(_ statement: String) -> String {
        return "(\(self)) AND (\(statement))"
    }

    static func &&(lhs: String, rhs: String) -> String {
        return lhs.and(rhs)
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
        3: { db in },
        4: { db in },
        5: { db in },
        6: { db in },
        7: { db in },
        8: { db in },
        9: { db in

            // Since there's no truly persistent information in the database up to this point, it's safe to entirely
            // delete and recreate the database. It also has the happy side effect that it brings the base schema into
            // one common place to make it easier to read.

            // Clean up the existing tables.
            try db.run(Schema.items.drop(ifExists: true))
            try db.run(Schema.items_to_tags.drop(ifExists: true))
            try db.run(Schema.tags.drop(ifExists: true))

            print("create the items table...")
            try db.run(Schema.items.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.identifier, unique: true)
                t.column(Schema.title)
                t.column(Schema.url, unique: true)
                t.column(Schema.date)
            })
            try db.run(Schema.items.createIndex(Schema.identifier, ifNotExists: true))

            print("create the tags table...")
            try db.run(Schema.tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.name, unique: true, collate: .nocase)
            })

            print("create the items_to_tags table...")
            try db.run(Schema.items_to_tags.create { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.item_id)
                t.column(Schema.tag_id)
                t.unique(Schema.item_id, Schema.tag_id)
                t.foreignKey(Schema.item_id, references: Schema.items, Schema.id, delete: .cascade)
                t.foreignKey(Schema.tag_id, references: Schema.tags, Schema.id, delete: .cascade)
            })

        },
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
            try self.syncQueue_enableForeignKeys()
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

    fileprivate func syncQueue_migrate() throws {
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

    fileprivate func syncQueue_enableForeignKeys() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try db.run("PRAGMA foreign_keys = ON")
    }

    fileprivate func syncQueue_notifyObservers() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let observers = self.observers
        DispatchQueue.global(qos: .background).async {
            for observer in observers {
                observer.databaseDidUpdate(database: self)
            }
        }
    }

    fileprivate func syncQueue_item(identifier: String) throws -> Item {
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

    fileprivate func syncQueue_fetchOrInsertTag(name: String) throws -> Int64 {
        if let id = try? syncQueue_tag(name: name) {
            return id
        }
        let id = try db.run(Schema.tags.insert(
            Schema.name <- name
        ))
        return id
    }

    fileprivate func syncQueue_tag(name: String) throws -> Int64 {
        let results = try db.prepare(Schema.tags.filter(Schema.name == name).limit(1)).map { row in
            try row.get(Schema.id)
        }
        guard let result = results.first else {
            throw BookmarksError.tagNotFound(name: name)
        }
        return result
    }

    fileprivate func syncQueue_tags(itemIdentifier: String) throws -> Set<String> {
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

    fileprivate func syncQueue_insertOrReplace(item: Item) throws {
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
        try syncQueue_pruneTags()
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

    fileprivate func syncQueue_pruneTags() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try self.db.run("""
            DELETE
            FROM
                tags
            WHERE
                id NOT IN (
                    SELECT
                        tag_id
                    FROM
                        items_to_tags
                )
            """)
    }

    // TODO: Clean up database tags when the last item is removed #141
    //       https://github.com/inseven/bookmarks/issues/141
    public func delete(identifier: String, completion: @escaping (Swift.Result<Int, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { () -> Int in
                        let count = try self.db.run(Schema.items.filter(Schema.identifier == identifier).delete())
                        try self.syncQueue_pruneTags()
                        return count
                    }
                    self.syncQueue_notifyObservers()
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func delete(tag: String, completion: @escaping (Swift.Result<Int, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { () -> Int in
                        try self.db.run(Schema.tags.filter(Schema.name == tag).delete())
                    }
                    self.syncQueue_notifyObservers()
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func syncQueue_items(where whereClause: String) throws -> [Item] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let selectQuery = """
            SELECT
                identifier,
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
                )
            ON
                items.id == item_id
            WHERE \(whereClause)
            ORDER BY
                date DESC
            """

        let statement = try db.prepare(selectQuery)
        let items = try statement.map { row -> Item in
            return Item(identifier: try row.string(0),
                        title: try row.string(1),
                        url: try row.url(2),
                        tags: try row.set(3),
                        date: try row.date(4))
        }

        return items
    }

    public func syncQueue_items(query: QueryDescription) throws -> [Item] {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        return try syncQueue_items(where: query.sql)
    }

    public func items(query: QueryDescription = True(), completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<[Item], Error> {
                try self.syncQueue_items(query: query)
            }
            completion(result)
        }
    }

    // TODO: Remove this method.
    public func items(filter: String? = nil, tags: [String]? = nil, completion: @escaping (Swift.Result<[Item], Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<[Item], Error> {
                var query: QueryDescription = True()
                if let filter = filter {
                    query = And(query, MatchesFilter(filter))
                }
                if let tags = tags {
                    if tags.isEmpty {
                        query = And(query, Untagged())
                    } else {
                        var tagsQueryDescription: QueryDescription = True()
                        for queryDescription in tags.map({ HasTag($0) }) {  // TODO Reduce
                            tagsQueryDescription = And(tagsQueryDescription, queryDescription)
                        }
                        query = And(query, tagsQueryDescription)
                    }
                }
                return try self.syncQueue_items(query: query)
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
