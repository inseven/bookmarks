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

extension Item {

    convenience init(title: String,
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

class DatabaseTests: XCTestCase {

    var temporaryDatabaseUrl: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("store.db")
    }

    // TODO: Update to throwing properties when adopting Swift 5.5 #142
    //       https://github.com/inseven/bookmarks/issues/142
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

    func testSingleQuery() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 0))

        try database.insertOrUpdate(items: [item1, item2])

        let tags = try database.tags()
        XCTAssertEqual(tags, Set(["example", "website", "cheese"]))

        let fetchedItem1 = try database.item(identifier: item1.identifier)
        XCTAssertEqual(fetchedItem1, item1)
        let fetchedItem2 = try database.item(identifier: item2.identifier)
        XCTAssertEqual(fetchedItem2, item2)
    }

    func testMultipleQuery() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        try database.insertOrUpdate(items: [item1, item2])

        XCTAssertEqual(try database.tags(), Set(["example", "website", "cheese"]))
        XCTAssertEqual(try database.items(), [item2, item1])
    }

    func testItemDeletion() throws {
        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://fromage.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        try database.insertOrUpdate(items: [item1, item2])
        try database.deleteItems([item1])

        XCTAssertEqual(try database.tags(), Set(["website", "cheese"]))
        XCTAssertEqual(try database.items(), [item2])
    }

    func testItemNotes() throws {
        let notes = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus blandit nec mauris quis feugiat."
        let item = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0),
                         notes: notes)
        _ = try database.insertOrUpdate(item: item)
        let fetchedItem = try database.item(identifier: item.identifier)
        XCTAssertEqual(item, fetchedItem)
        XCTAssertEqual(fetchedItem.notes, notes)

        let update = item.setting(notes: "Cheese")
        _ = try database.insertOrUpdate(item: update)
        let fetchedUpdate = try database.item(identifier: item.identifier)
        XCTAssertNotEqual(item, update)
        XCTAssertEqual(update, fetchedUpdate)
        XCTAssertEqual(fetchedUpdate.notes, "Cheese")
    }

    func testDeleteItemFailsOnMissingItem() throws {
        let identifier = UUID().uuidString
        XCTAssertThrowsError(try database.deleteItem(identifier: identifier)) { error in
            XCTAssertEqual(error as! BookmarksError, BookmarksError.itemNotFound(identifier: identifier))
        }

    }

    func testItemUpdateCleansUpTags() throws {

        let item = Item(title: "Example",
                        url: URL(string: "https://example.com")!,
                        tags: ["example", "website"],
                        date: Date(timeIntervalSince1970: 0))
        try database.insertOrUpdate(items: [item])
        XCTAssertEqual(try database.tags(), Set(["example", "website"]))

        let updatedItem = Item(title: "Example",
                               url: item.url,
                               tags: ["website", "cheese"],
                               date: item.date)
        try database.insertOrUpdate(items: [updatedItem])
        XCTAssertEqual(try database.tags(), Set(["website", "cheese"]))
    }

    func testItemFilter() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://blue.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        let item3 = Item(title: "Fromage and Cheese",
                         url: URL(string: "https://fruit.co.uk")!,
                         tags: ["robert", "website", "strawberries"],
                         date: Date(timeIntervalSince1970: 20))

        try database.insertOrUpdate(items: [item1, item2, item3])

        XCTAssertEqual(try database.items(query: Search(".com")), [item2, item1])
        XCTAssertEqual(try database.items(query: Search(".COM")), [item2, item1])
        XCTAssertEqual(try database.items(query: Search("example.COM")), [item1])
        XCTAssertEqual(try database.items(query: Search("example.com")), [item1])
        XCTAssertEqual(try database.items(query: Search("Example")), [item1])
        XCTAssertEqual(try database.items(query: Search("EXaMPle")), [item1])
        XCTAssertEqual(try database.items(query: Search("amp")), [item1])
        XCTAssertEqual(try database.items(query: Search("Cheese")), [item3, item2])
        XCTAssertEqual(try database.items(query: Search("Cheese co")), [item3, item2])
        XCTAssertEqual(try database.items(query: Search("Cheese com")), [item2])
        XCTAssertEqual(try database.items(query: Search("Fromage CHEESE")), [item3])
    }

    func testItemFilterWithTags() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://blue.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        let item3 = Item(title: "Fromage and Cheese",
                         url: URL(string: "https://fruit.co.uk")!,
                         tags: ["robert", "website", "strawberries", "cheese"],
                         date: Date(timeIntervalSince1970: 20))

        try database.insertOrUpdate(items: [item1, item2, item3])

        XCTAssertEqual(try database.items(query: Search("Cheese") && Tag("cheese")), [item3, item2])
        XCTAssertEqual(try database.items(query: Search("Cheese co") && Tag("cheese")), [item3, item2])
        XCTAssertEqual(try database.items(query: Search("Cheese com") && Tag("cheese")), [item2])
        XCTAssertEqual(try database.items(query: Search("Fromage CHEESE") && Tag("cheese")), [item3])
        XCTAssertEqual(try database.items(query: Search("strawberries") && Tag("cheese")), [item3])
    }

    func testItemFilterEmptyTags() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: [],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://blue.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        let item3 = Item(title: "Fromage and Cheese",
                         url: URL(string: "https://fruit.co.uk")!,
                         tags: [],
                         date: Date(timeIntervalSince1970: 20))

        try database.insertOrUpdate(items: [item1, item2, item3])

        XCTAssertEqual(try database.items(query: Untagged()), [item3, item1])
        XCTAssertEqual(try database.items(query: Untagged() && Search("co")), [item3, item1])
        XCTAssertEqual(try database.items(query: Untagged() && Search("com")), [item1])
    }

    func testTags() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://blue.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        let item3 = Item(title: "Fromage and Cheese",
                         url: URL(string: "https://fruit.co.uk")!,
                         tags: ["robert", "website", "strawberries"],
                         date: Date(timeIntervalSince1970: 20))

        try database.insertOrUpdate(items: [item1, item2, item3])

        XCTAssertEqual(try database.tags(), Set(["example", "website", "cheese", "robert", "strawberries"]))
    }

    func testDeleteTags() throws {

        let item1 = Item(title: "Example",
                         url: URL(string: "https://example.com")!,
                         tags: ["example", "website"],
                         date: Date(timeIntervalSince1970: 0))

        let item2 = Item(title: "Cheese",
                         url: URL(string: "https://blue.com")!,
                         tags: ["cheese", "website"],
                         date: Date(timeIntervalSince1970: 10))

        let item3 = Item(title: "Fromage and Cheese",
                         url: URL(string: "https://fruit.co.uk")!,
                         tags: ["robert", "website", "strawberries"],
                         date: Date(timeIntervalSince1970: 20))

        try database.insertOrUpdate(items: [item1, item2, item3])
        XCTAssertEqual(try database.tags(), Set(["example", "website", "cheese", "robert", "strawberries"]))

        try database.deleteTag(tag: "website")
        XCTAssertEqual(try database.tags(), Set(["example", "cheese", "robert", "strawberries"]))
        XCTAssertEqual(try database.items(), [item3, item2, item1].map { item in
            var tags = item.tags
            tags.remove("website")
            return Item(identifier: item.identifier,
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
