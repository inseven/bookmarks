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

    func testSingleQuery() {
        guard let database = try? Database(path: temporaryDatabaseUrl) else {
            XCTFail("Failed to create database")
            return
        }
        XCTAssertNotNil(database)

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

        do {
            _ = try AsyncOperation({ database.insertOrUpdate(item1, completion: $0) }).wait()
            _ = try AsyncOperation({ database.insertOrUpdate(item2, completion: $0) }).wait()

            let tags = try AsyncOperation({ database.tags(completion: $0) }).wait()
            XCTAssertEqual(tags, Set(["example", "website", "cheese"]))

            let fetchedItem1 = try AsyncOperation({ database.item(identifier: item1.identifier, completion: $0) }).wait()
            XCTAssertEqual(fetchedItem1, item1)
            let fetchedItem2 = try AsyncOperation({ database.item(identifier: item2.identifier, completion: $0) }).wait()
            XCTAssertEqual(fetchedItem2, item2)
        } catch {
            XCTFail("Failed with error \(error)")
        }

    }

    func testMultipleQuery() {
        guard let database = try? Database(path: temporaryDatabaseUrl) else {
            XCTFail("Failed to create database")
            return
        }
        XCTAssertNotNil(database)

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

        do {
            _ = try AsyncOperation({ database.insertOrUpdate(item1, completion: $0) }).wait()
            _ = try AsyncOperation({ database.insertOrUpdate(item2, completion: $0) }).wait()

            let tags = try AsyncOperation({ database.tags(completion: $0) }).wait()
            XCTAssertEqual(tags, Set(["example", "website", "cheese"]))

            let fetchedItems = try AsyncOperation({ database.items(completion: $0) }).wait()
            XCTAssertEqual(fetchedItems, [item2, item1])
        } catch {
            XCTFail("Failed with error \(error)")
        }

    }

    func testSingleDeletion() {
        guard let database = try? Database(path: temporaryDatabaseUrl) else {
            XCTFail("Failed to create database")
            return
        }
        XCTAssertNotNil(database)

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

        do {
            _ = try AsyncOperation({ database.insertOrUpdate(item1, completion: $0) }).wait()
            _ = try AsyncOperation({ database.insertOrUpdate(item2, completion: $0) }).wait()
            _ = try AsyncOperation({ database.delete(identifier: item1.identifier, completion: $0) }).wait()

            let tags = try AsyncOperation({ database.tags(completion: $0) }).wait()
            XCTAssertEqual(tags, Set(["example", "website", "cheese"]))

            let fetchedItems = try AsyncOperation({ database.items(completion: $0) }).wait()
            XCTAssertEqual(fetchedItems, [item2])
        } catch {
            XCTFail("Failed with error \(error)")
        }

    }

    // TODO: Lowercase tags

}
