// Copyright (c) 2020-2023 InSeven Limited
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
import SwiftUI

import SQLite

public protocol DatabaseObserver {
    var id: UUID { get }
    func databaseDidUpdate(database: Database)
}

extension Bookmark {

    init(row: Row) throws {
        self.init(identifier: try row.get(Database.Schema.identifier),
                  title: try row.get(Database.Schema.title),
                  url: try row.get(Database.Schema.url).url,
                  tags: [],
                  date: try row.get(Database.Schema.date),
                  toRead: try row.get(Database.Schema.toRead),
                  shared: try row.get(Database.Schema.shared),
                  notes: try row.get(Database.Schema.notes))
    }

}

extension Connection {

    public var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue)") }
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
        static let toRead = Expression<Bool>("to_read")
        static let shared = Expression<Bool>("shared")
        static let notes = Expression<String>("notes")
        static let name = Expression<String>("name")
        static let itemId = Expression<Int64>("item_id")
        static let tagId = Expression<Int64>("tag_id")

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
                t.column(Schema.itemId)
                t.column(Schema.tagId)
                t.unique(Schema.itemId, Schema.tagId)
                t.foreignKey(Schema.itemId, references: Schema.items, Schema.id, delete: .cascade)
                t.foreignKey(Schema.tagId, references: Schema.tags, Schema.id, delete: .cascade)
            })

        },
        10: { db in
            print("add the to_read column...")
            try db.run(Schema.items.addColumn(Schema.toRead, defaultValue: false))
        },
        11: { db in
            print("add the shared column...")
            try db.run(Schema.items.addColumn(Schema.shared, defaultValue: false))
        },
        12: { db in
            print("add the notes column...")
            try db.run(Schema.items.addColumn(Schema.notes, defaultValue: ""))
        },
        13: { db in
            print("add index on items.url...")
            try db.run(Schema.items.createIndex(Schema.url))
        },
    ]

    static var schemaVersion: Int32 = Array(migrations.keys).max() ?? 0

    let path: URL
    var syncQueue = DispatchQueue(label: "Database.syncQueue")
    var db: Connection  // Synchronized on syncQueue
    var observers: [DatabaseObserver] = []  // Synchronized on syncQueue

    var updatePublisher: Publishers.Concatenate<Publishers.Sequence<Array<Database>, Never>, DatabasePublisher> {
        return DatabasePublisher(database: self)
            .prepend(self)
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

    fileprivate func syncQueue_bookmark(identifier: String) throws -> Bookmark {
        let run = try db.prepare(Schema.items.filter(Schema.identifier == identifier).limit(1)).map(Bookmark.init)
        guard let result = run.first else {
            throw BookmarksError.bookmarkNotFoundByIdentifier(identifier)
        }
        let tags = try syncQueue_tags(bookmarkIdentifier: result.identifier)
        return Bookmark(identifier: result.identifier,
                        title: result.title,
                        url: result.url,
                        tags: Set(tags),
                        date: result.date,
                        toRead: result.toRead,
                        shared: result.shared,
                        notes: result.notes)
    }

    fileprivate func syncQueue_bookmark(url: URL) throws -> Bookmark {
        let run = try db.prepare(Schema.items.filter(Schema.url == url.absoluteString).limit(1)).map(Bookmark.init)
        guard let result = run.first else {
            throw BookmarksError.bookmarkNotFoundByURL(url)
        }
        let tags = try syncQueue_tags(bookmarkIdentifier: result.identifier)
        return Bookmark(identifier: result.identifier,
                        title: result.title,
                        url: result.url,
                        tags: Set(tags),
                        date: result.date,
                        toRead: result.toRead,
                        shared: result.shared,
                        notes: result.notes)
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

    fileprivate func syncQueue_tags(bookmarkIdentifier: String) throws -> Set<String> {
        Set(try self.db.prepare(Schema.items_to_tags
                                    .join(Schema.items, on: Schema.items_to_tags[Schema.itemId] == Schema.items[Schema.id])
                                    .join(Schema.tags, on: Schema.items_to_tags[Schema.tagId] == Schema.tags[Schema.id])
                                    .filter(Schema.identifier == bookmarkIdentifier))
                .map { row -> String in
                    try row.get(Schema.tags[Schema.name])
                })
    }

    public func tags(completion: @escaping (Swift.Result<[Tag], Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result {
                try self.syncQueue_tags()
            }
            completion(result)
        }
    }

    public func tags() async throws -> [Tag] {
        try await withCheckedThrowingContinuation { continuation in
            tags { result in
                continuation.resume(with: result)
            }
        }
    }

    public func bookmark(identifier: String, completion: @escaping (Swift.Result<Bookmark, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { try self.syncQueue_bookmark(identifier: identifier) }
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func bookmark(identifier: String) async throws -> Bookmark {
        return try await withCheckedThrowingContinuation { continuation in
            syncQueue.async {
                let result = Swift.Result<Bookmark, Error> {
                    try self.syncQueue_bookmark(identifier: identifier)
                }
                continuation.resume(with: result)
            }
        }
    }

    public func bookmark(url: URL, completion: @escaping (Swift.Result<Bookmark, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { try self.syncQueue_bookmark(url: url) }
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }


    fileprivate func syncQueue_insertOrReplaceBookmark(_ bookmark: Bookmark) throws {
        let tags = try bookmark.tags.map { try syncQueue_fetchOrInsertTag(name: $0) }
        let itemId = try self.db.run(
            Schema.items.insert(or: .replace,
                                Schema.identifier <- bookmark.identifier,
                                Schema.title <- bookmark.title,
                                Schema.url <- bookmark.url.absoluteString,
                                Schema.date <- bookmark.date,
                                Schema.toRead <- bookmark.toRead,
                                Schema.shared <- bookmark.shared,
                                Schema.notes <- bookmark.notes
            ))
        for tagId in tags {
            _ = try self.db.run(
                Schema.items_to_tags.insert(or: .replace,
                                            Schema.itemId <- itemId,
                                            Schema.tagId <- tagId))
        }
        try syncQueue_pruneTags()
    }

    private func insertOrUpdateBookmark(_ bookmark: Bookmark, completion: @escaping (Swift.Result<Bookmark, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            let result = Swift.Result<Bookmark, Error> {
                try self.db.transaction {
                    // N.B. While it would be possible to use an insert or replace strategy directly, we want to ensure
                    // we only notify observers if the data has actually changed so we instead fetch the item and
                    // compare.
                    if let existingBookmark = try? self.syncQueue_bookmark(identifier: bookmark.identifier) {
                        if existingBookmark != bookmark {
                            try self.syncQueue_insertOrReplaceBookmark(bookmark)
                            self.syncQueue_notifyObservers()
                        }
                    } else {
                        try self.syncQueue_insertOrReplaceBookmark(bookmark)
                        self.syncQueue_notifyObservers()
                    }
                }
                return bookmark
            }
            completion(result)
        }
    }

    public func insertOrUpdateBookmark(_ bookmark: Bookmark) async throws -> Bookmark {
        try await withCheckedThrowingContinuation { continuation in
            self.insertOrUpdateBookmark(bookmark) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func insertOrUpdateBookmarks(_ bookmarks: [Bookmark]) async throws {
        for bookmark in bookmarks {
            _ = try await insertOrUpdateBookmark(bookmark)
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

    public func clear(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { () -> Void in
                        try self.db.run(Schema.items.delete())
                        try self.db.run(Schema.tags.delete())
                        try self.db.run(Schema.items_to_tags.delete())
                    }
                    self.syncQueue_notifyObservers()
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func deleteBookmark(identifier: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            do {
                try self.db.transaction {
                    let result = Swift.Result { () -> Void in
                        let count = try self.db.run(Schema.items.filter(Schema.identifier == identifier).delete())
                        if count == 0 {
                            throw BookmarksError.bookmarkNotFoundByIdentifier(identifier)
                        }
                        try self.syncQueue_pruneTags()
                    }
                    self.syncQueue_notifyObservers()
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func deleteBookmark(identifier: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            deleteBookmark(identifier: identifier) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func deleteBookmarks(_ bookmarks: [Bookmark]) async throws {
        for bookmark in bookmarks {
            try await deleteBookmark(identifier: bookmark.identifier)
        }
    }

    private func deleteTag(tag: String, completion: @escaping (Swift.Result<Int, Error>) -> Void) {
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

    public func deleteTag(tag: String) async throws {
        _ = try await withCheckedThrowingContinuation { continuation in
            deleteTag(tag: tag) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func syncQueue_tags() throws -> [Tag] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let selectQuery = """
            SELECT
                LOWER(name),
                COUNT(name)
            FROM
                items_to_tags
            JOIN
                tags
            ON
                tags.id == items_to_tags.tag_id
            GROUP BY
                LOWER(name)
            """

        let statement = try db.prepare(selectQuery)
        let tags = try statement.map { row in
            return Tag(name: try row.string(0),
                       count: try row.integer(1))
        }

        return tags
    }

    public func syncQueue_bookmarks(where whereClause: String) throws -> [Bookmark] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let selectQuery = """
            SELECT
                identifier,
                title,
                url,
                tags,
                date,
                to_read,
                shared,
                notes
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
        let bookmarks = try statement.map { row in
            return Bookmark(identifier: try row.string(0),
                            title: try row.string(1),
                            url: try row.url(2),
                            tags: try row.set(3),
                            date: try row.date(4),
                            toRead: try row.bool(5),
                            shared: try row.bool(6),
                            notes: try row.string(7))
        }

        return bookmarks
    }

    public func syncQueue_count(where whereClause: String) throws -> Int {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let selectQuery = """
            SELECT
                COUNT(*)
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

        return Int(try db.scalar(selectQuery) as! Int64)
    }

    public func bookmarks<T: QueryDescription>(query: T) async throws -> [Bookmark] {
        return try await withCheckedThrowingContinuation { continuation in
            syncQueue.async {
                let result = Swift.Result<[Bookmark], Error> {
                    try self.syncQueue_bookmarks(where: query.sql)
                }
                continuation.resume(with: result)
            }
        }
    }

    public func count<T: QueryDescription>(query: T) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            syncQueue.async {
                let result = Swift.Result<Int, Error> {
                    try self.syncQueue_count(where: query.sql)
                }
                continuation.resume(with: result)
            }
        }
    }

    private func identifiers(completion: @escaping (Swift.Result<[String], Error>) -> Void) {
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

    public func identifiers() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            identifiers { result in
                continuation.resume(with: result)
            }
        }
    }

}
