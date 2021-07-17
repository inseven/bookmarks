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

public class Updater {

    let database: Database
    let pinboard: Pinboard

    public init(database: Database, pinboard: Pinboard) {
        self.database = database
        self.pinboard = pinboard
    }

    public func start() {
        print("Updating bookmarks...")
        pinboard.posts_all { [weak self] (result) in
            switch (result) {
            case .failure(let error):
                print("Failed to fetch the posts with error \(error)")
            case .success(let posts):
                guard let self = self else {
                    return
                }

                do {

                    // Store the seen identifiers to determine what to delete.
                    var identifiers = Set<String>()

                    // Insert or update items.
                    for post in posts {
                        guard
                            let url = post.href,
                            let date = post.time else {
                                continue
                        }
                        let item = Item(identifier: post.hash,
                                        title: post.description ?? "",
                                        url: url,
                                        tags: Set(post.tags),
                                        date: date)
                        identifiers.insert(item.identifier)
                        _ = try AsyncOperation({ self.database.insertOrUpdate(item, completion: $0) }).wait()
                    }

                    // Delete missing items.
                    let allIdentifiers = try AsyncOperation(self.database.identifiers).wait()
                    let deletedIdentifiers = Set(allIdentifiers).subtracting(identifiers)
                    for identifier in deletedIdentifiers {
                        let item = try AsyncOperation({ self.database.item(identifier: identifier, completion: $0) }).wait()
                        print("deleting \(item)...")
                        _ = try AsyncOperation({ self.database.delete(identifier: identifier, completion: $0) }).wait()
                    }
                    print("Complete.")

                } catch {
                    print("Failed to update items with error \(error)")
                }

            }
        }
    }

}
