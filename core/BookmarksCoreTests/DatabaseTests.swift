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

class DatabaseTests: XCTestCase {

    // TODO: Actually do something nice with these temporary files.

    var temporaryDatabaseUrl: URL {
        // TODO: Create a temporary directory for this that is cleaned up at the end.
        FileManager.default.temporaryDirectory.appendingPathComponent("store.db")
    }

    func testInsert() {

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
            XCTAssertEqual(Set(tags.map({ $0.name })), Set(["example", "website", "cheese"]))

            let fetchedItem = try AsyncOperation({ database.item(identifier: item1.identifier, completion: $0) }).wait()
            XCTAssertNotNil(fetchedItem)
            XCTAssertEqual(fetchedItem, item1)
        } catch {
            XCTFail("Failed with error \(error)")
        }

    }




}
