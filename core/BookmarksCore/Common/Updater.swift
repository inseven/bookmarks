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

extension Pinboard {

    func posts_update() throws -> Update {
        try AsyncOperation({ self.posts_update(completion: $0) }).wait()
    }

    func posts_all() throws -> [Post] {
        try AsyncOperation({ self.posts_all(completion: $0) }).wait()
    }

}

public class Updater {

    static var updateTimeoutSeconds = 5 * 60.0

    let syncQueue = DispatchQueue(label: "Updater.syncQueue")

    let database: Database
    let pinboard: Pinboard

    var timer: Timer? = nil

    var lastUpdate: Date? = nil  // Synchronized on syncQueue

    public init(database: Database, pinboard: Pinboard) {
        self.database = database
        self.pinboard = pinboard
    }

    fileprivate func syncQueue_update() {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        print("updating...")

        do {

            // Check to see when the bookmarks were last updated and don't update if there are no new changes.
            let update = try self.pinboard.posts_update()
            if let lastUpdate = self.lastUpdate,
               lastUpdate >= update.updateTime {
                print("skipping empty update")
                return
            }

            // Get the posts.
            let posts = try self.pinboard.posts_all()

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
            // TODO: Move the blocking database APIs into BookmarksCore #170
            //       https://github.com/inseven/bookmarks/issues/170
            let allIdentifiers = try AsyncOperation(self.database.identifiers).wait()
            let deletedIdentifiers = Set(allIdentifiers).subtracting(identifiers)
            for identifier in deletedIdentifiers {
                let item = try AsyncOperation({ self.database.item(identifier: identifier, completion: $0) }).wait()
                print("deleting \(item)...")
                _ = try AsyncOperation({ self.database.delete(identifier: identifier, completion: $0) }).wait()
            }
            print("update complete")

            // Update the last update date.
            self.lastUpdate = update.updateTime

        } catch {
            print("failed to update items with error \(error)")
        }
    }

    public func start() {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            timer = Timer.scheduledTimer(withTimeInterval: Self.updateTimeoutSeconds, repeats: true) { [weak self] timer in
                guard let self = self else {
                    return
                }
                self.syncQueue.async {
                    self.syncQueue_update()
                }
            }
        }
    }

    public func update() {
        syncQueue.async {
            self.syncQueue_update()
        }
    }

}
