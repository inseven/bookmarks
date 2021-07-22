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

import XCTest
@testable import BookmarksCore

// TODO: Are the Pinboard item identifiers the URL, and if so should we have a convenience constructor for that?

extension Item {

    func removingTags() -> Item {
        Item(identifier: identifier,
             title: title,
             url: url,
             tags: Set(),
             date: date)
    }

}

extension Array where Element == Item {

    func removingTags() -> [Item] {
        self.map { $0.removingTags() }
    }

}


extension Database {

    // TODO: Rename to insertOrUpdate
    func insert(_ items: [Item]) throws {
        for item in items {
            _ = try AsyncOperation({ self.insertOrUpdate(item, completion: $0) }).wait()
        }
    }

    func delete(_ items: [Item]) throws {
        for item in items {
            _ = try AsyncOperation({ self.delete(identifier: item.identifier, completion: $0) }).wait()
        }
    }

    func items() throws -> [Item] {
        try AsyncOperation({ self.items(completion: $0) }).wait()
    }

    func tags() throws -> Set<String> {
        try AsyncOperation({ self.tags(completion: $0) }).wait()
    }

}

// TODO: Use a unique temporary directory for the database tests #140
//       https://github.com/inseven/bookmarks/issues/140
class DatabaseTests: XCTestCase {

    var temporaryDatabaseUrl: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("store.db")
    }

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

    func testSingleQuery() throws {
        let database = try Database(path: temporaryDatabaseUrl)

        let item1 = Item(identifier: UUID().uuidString,
                         title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(identifier: UUID().uuidString,
                         title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 0))

        try database.insert([item1, item2])

        let tags = try AsyncOperation({ database.tags(completion: $0) }).wait()
        XCTAssertEqual(tags, Set(["example", "website", "cheese"]))

        // TODO: Make this a multi-item fetch?
        let fetchedItem1 = try AsyncOperation({ database.item(identifier: item1.identifier, completion: $0) }).wait()
        XCTAssertEqual(fetchedItem1, item1)
        let fetchedItem2 = try AsyncOperation({ database.item(identifier: item2.identifier, completion: $0) }).wait()
        XCTAssertEqual(fetchedItem2, item2)
    }

    func testMultipleQuery() throws {
        let database = try Database(path: temporaryDatabaseUrl)

        let item1 = Item(identifier: UUID().uuidString,
                         title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(identifier: UUID().uuidString,
                         title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        try database.insert([item1, item2])

        XCTAssertEqual(try database.tags(), Set(["example", "website", "cheese"]))
        XCTAssertEqual(try database.items(), [item2, item1].removingTags())
    }

    func testItemDeletion() throws {
        // TODO: This test is actually broken.
        let database = try Database(path: temporaryDatabaseUrl)

        let item1 = Item(identifier: UUID().uuidString,
                         title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(identifier: UUID().uuidString,
                         title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        try database.insert([item1, item2])
        try database.delete([item1])

        XCTAssertEqual(try database.tags(), Set(["website", "cheese"]))
        XCTAssertEqual(try database.items(), [item2].removingTags())
    }

    // TODO: Test item update?

    // TODO: Updating should also remove tags.

    func testItemUpdateCleansUpTags() throws {
        let database = try Database(path: temporaryDatabaseUrl)

        let item = Item(identifier: UUID().uuidString,
                        title: "Example",
                        url: URL(string: "https://example.com")!,
                        tags: ["example", "website"],
                        date: Date(timeIntervalSince1970: 0))
        try database.insert([item])
        XCTAssertEqual(try database.tags(), Set(["example", "website"]))

        let updatedItem = Item(identifier: item.identifier,
                               title: "Example",
                               url: item.url,
                               tags: ["website", "cheese"],
                               date: item.date)
        try database.insert([updatedItem])
        XCTAssertEqual(try database.tags(), Set(["website", "cheese"]))
    }

    func testItemFilter() throws {
        // TODO: Actually update this test to do the correct thing.
        let database = try Database(path: temporaryDatabaseUrl)

        let item1 = Item(identifier: UUID().uuidString,
                         title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(identifier: UUID().uuidString,
                         title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        try database.insert([item1, item2])

        XCTAssertEqual(try database.tags(), Set(["example", "website", "cheese"]))
        XCTAssertEqual(try database.items(), [item2, item1].removingTags())
    }

    // TODO: Delete tags.

    // TODO: Lowercase tags

}
