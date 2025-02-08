// Copyright (c) 2020-2025 Jason Morley
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

import XCTest
@testable import BookmarksCore

public func XCTAssertEqualAsync<T>(_ expression1: @autoclosure () async throws -> T,
                                   _ expression2: @autoclosure () async throws -> T,
                                   _ message: @autoclosure () -> String = "",
                                   file: StaticString = #filePath,
                                   line: UInt = #line) async where T : Equatable {
    do {
        let result1 = try await expression1()
        let result2 = try await expression2()
        XCTAssertEqual(result1, result2, file: file, line: line)
    } catch {
        XCTFail(message(), file: file, line: line)
    }
}

public func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T,
                                         _ message: @autoclosure () -> String = "",
                                         file: StaticString = #filePath,
                                         line: UInt = #line,
                                         _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }

}

extension Bookmark {

    init(title: String,
                     url: URL,
                     tags: Set<String>,
                     date: Date,
                     toRead: Bool = false,
                     shared: Bool = false,
                     notes: String = "",
                     thumbnail: SafeImage? = nil) {
        self.init(identifier: UUID().uuidString,
                  title: title,
                  url: url,
                  tags: tags,
                  date: date,
                  toRead: toRead,
                  shared: shared,
                  notes: notes,
                  thumbnail: thumbnail)
    }

}

extension Array where Element == Database.Tag {

    func names() -> [String] {
        return map { tag in
            return tag.name
        }
    }

}

class DatabaseTests: XCTestCase {

    var temporaryDatabaseUrl: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("store.db")
    }

    // TODO: Use a unique temporary directory for the database tests #140
    //       https://github.com/inseven/bookmarks/issues/140
    lazy var database: Database = {
        return try! Database(path: temporaryDatabaseUrl)
    }()

    func removeDatabase() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: temporaryDatabaseUrl.path) {
            try! fileManager.removeItem(at: temporaryDatabaseUrl)
        }
    }

    override func setUp() {
        removeDatabase()
    }

    override func tearDown() {
        removeDatabase()
    }

    func testSingleQuery() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://fromage.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 0))

        try await database.insertOrUpdateBookmarks([item1, item2])

        let tags = try await database.tags()
        XCTAssertEqual(tags.names(), ["cheese", "example", "website"])

        let fetchedItem1 = try await database.bookmark(identifier: item1.identifier)
        XCTAssertEqual(fetchedItem1, item1)
        let fetchedItem2 = try await database.bookmark(identifier: item2.identifier)
        XCTAssertEqual(fetchedItem2, item2)
    }

    func testMultipleQuery() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://fromage.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        try await database.insertOrUpdateBookmarks([item1, item2])

        await XCTAssertEqualAsync(try await database.tags().names(), ["cheese", "example", "website"])
        await XCTAssertEqualAsync(try await database.bookmarks(query: True()), [item2, item1])
    }

    func testItemDeletion() async throws {
        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://fromage.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        try await database.insertOrUpdateBookmarks([item1, item2])
        try await database.delete(bookmarks: [item1])

        await XCTAssertEqualAsync(try await database.tags().names(), ["cheese", "website"])
        await XCTAssertEqualAsync(try await database.bookmarks(query: True()), [item2])
    }

    func testItemNotes() async throws {
        let notes = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus blandit nec mauris quis feugiat."
        let item = Bookmark(title: "Example",
                            url: URL(string: "https://example.com")!,
                            tags: ["example", "website"],
                            date: Date(timeIntervalSince1970: 0),
                            notes: notes)
        _ = try await database.insertOrUpdate(bookmark: item)
        let fetchedItem = try await database.bookmark(identifier: item.identifier)
        XCTAssertEqual(item, fetchedItem)
        XCTAssertEqual(fetchedItem.notes, notes)

        var update = item
        update.notes = "Cheese"
        _ = try await database.insertOrUpdate(bookmark: update)
        let fetchedUpdate = try await database.bookmark(identifier: item.identifier)
        XCTAssertNotEqual(item, update)
        XCTAssertEqual(update, fetchedUpdate)
        XCTAssertEqual(fetchedUpdate.notes, "Cheese")
    }

    func testDeleteItemFailsOnMissingItem() async throws {
        let identifier = UUID().uuidString
        await XCTAssertThrowsErrorAsync(try await database.delete(bookmark: identifier)) { error in
            XCTAssertEqual(error as! BookmarksError, BookmarksError.bookmarkNotFoundByIdentifier(identifier))
        }
    }

    func testItemUpdateCleansUpTags() async throws {

        let item = Bookmark(title: "Example",
                            url: URL(string: "https://example.com")!,
                            tags: ["example", "website"],
                            date: Date(timeIntervalSince1970: 0))
        try await database.insertOrUpdateBookmarks([item])
        await XCTAssertEqualAsync(try await database.tags().names(), ["example", "website"])

        let updatedItem = Bookmark(title: "Example",
                                   url: item.url,
                                   tags: ["website", "cheese"],
                                   date: item.date)
        try await database.insertOrUpdateBookmarks([updatedItem])
        await XCTAssertEqualAsync(try await database.tags().names(), ["cheese", "website"])
    }

    func testItemFilter() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://blue.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        let item3 = Bookmark(title: "Fromage and Cheese",
                             url: URL(string: "https://fruit.co.uk")!,
                             tags: ["robert", "website", "strawberries"],
                             date: Date(timeIntervalSince1970: 20))

        try await database.insertOrUpdateBookmarks([item1, item2, item3])

        await XCTAssertEqualAsync(try await database.bookmarks(query: Search(".com")), [item2, item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search(".COM")), [item2, item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("example.COM")), [item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("example.com")), [item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Example")), [item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("EXaMPle")), [item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("amp")), [item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Cheese")), [item3, item2])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Cheese co")), [item3, item2])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Cheese com")), [item2])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Fromage CHEESE")), [item3])
    }

    func testItemFilterWithTags() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://blue.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        let item3 = Bookmark(title: "Fromage and Cheese",
                             url: URL(string: "https://fruit.co.uk")!,
                             tags: ["robert", "website", "strawberries", "cheese"],
                             date: Date(timeIntervalSince1970: 20))

        try await database.insertOrUpdateBookmarks([item1, item2, item3])

        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Cheese") && Tag("cheese")),
                                  [item3, item2])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Cheese co") && Tag("cheese")),
                                  [item3, item2])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Cheese com") && Tag("cheese")),
                                  [item2])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("Fromage CHEESE") && Tag("cheese")),
                                  [item3])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Search("strawberries") && Tag("cheese")),
                                  [item3])
    }

    func testItemFilterEmptyTags() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: [],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://blue.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        let item3 = Bookmark(title: "Fromage and Cheese",
                             url: URL(string: "https://fruit.co.uk")!,
                             tags: [],
                             date: Date(timeIntervalSince1970: 20))

        try await database.insertOrUpdateBookmarks([item1, item2, item3])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Untagged()), [item3, item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Untagged() && Search("co")), [item3, item1])
        await XCTAssertEqualAsync(try await database.bookmarks(query: Untagged() && Search("com")), [item1])
    }

    func testTags() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://blue.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        let item3 = Bookmark(title: "Fromage and Cheese",
                             url: URL(string: "https://fruit.co.uk")!,
                             tags: ["robert", "website", "strawberries"],
                             date: Date(timeIntervalSince1970: 20))

        try await database.insertOrUpdateBookmarks([item1, item2, item3])

        await XCTAssertEqualAsync(try await database.tags().names(),
                                  ["cheese", "example", "robert", "strawberries", "website"])
    }

    func testDeleteTags() async throws {

        let item1 = Bookmark(title: "Example",
                             url: URL(string: "https://example.com")!,
                             tags: ["example", "website"],
                             date: Date(timeIntervalSince1970: 0))

        let item2 = Bookmark(title: "Cheese",
                             url: URL(string: "https://blue.com")!,
                             tags: ["cheese", "website"],
                             date: Date(timeIntervalSince1970: 10))

        let item3 = Bookmark(title: "Fromage and Cheese",
                             url: URL(string: "https://fruit.co.uk")!,
                             tags: ["robert", "website", "strawberries"],
                             date: Date(timeIntervalSince1970: 20))

        try await database.insertOrUpdateBookmarks([item1, item2, item3])
        await XCTAssertEqualAsync(try await database.tags().names(),
                                  ["cheese", "example", "robert", "strawberries", "website"])

        try await database.delete(tag: "website")
        await XCTAssertEqualAsync(try await database.tags().names(),
                                  ["cheese", "example", "robert", "strawberries"])
        await XCTAssertEqualAsync(try await database.bookmarks(query: True()),
                                  [item3, item2, item1].map { item in
            var tags = item.tags
            tags.remove("website")
            return Bookmark(identifier: item.identifier,
                            title: item.title,
                            url: item.url,
                            tags: tags,
                            date: item.date,
                            toRead: item.toRead,
                            shared: item.shared,
                            notes: item.notes)
        })
    }

    // TODO: Check case sensitivity when selecting tags.\

}
