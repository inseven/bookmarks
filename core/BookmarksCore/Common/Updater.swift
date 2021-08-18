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

    fileprivate func syncQueue_update(force: Bool) {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        print("updating...")

        do {

            // Check to see when the bookmarks were last updated and don't update if there are no new changes.
            let update = try self.pinboard.postsUpdate()
            if let lastUpdate = self.lastUpdate,
               lastUpdate >= update.updateTime,
               !force {
                print("skipping empty update")
                return
            }

            // Get the posts.
            let posts = try self.pinboard.postsAll()

            var identifiers = Set<String>()

            // Insert or update bookmarks.
            for post in posts {
                guard
                    let url = post.href,
                    let date = post.time else {
                        continue
                }
                let bookmark = Bookmark(identifier: post.hash,
                                        title: post.description ?? "",
                                        url: url,
                                        tags: Set(post.tags),
                                        date: date,
                                        toRead: post.toRead,
                                        shared: post.shared,
                                        notes: post.extended)
                identifiers.insert(bookmark.identifier)
                _ = try self.database.insertOrUpdateBookmark(bookmark)
            }

            // Delete missing bookmarks.
            let allIdentifiers = try self.database.identifiers()
            let deletedIdentifiers = Set(allIdentifiers).subtracting(identifiers)
            for identifier in deletedIdentifiers {
                let bookmark = try self.database.bookmark(identifier: identifier)
                print("deleting \(bookmark)...")
                _ = try self.database.deleteBookmark(identifier: identifier)
            }
            print("update complete")

            // Update the last update date.
            self.lastUpdate = update.updateTime

        } catch {
            print("failed to update bookmarks with error \(error)")
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
                    self.syncQueue_update(force: true)
                }
            }
        }
    }

    public func update(force: Bool = false) {
        syncQueue.async {
            self.syncQueue_update(force: force)
        }
    }

    public func deleteBookmarks(_ bookmarks: [Bookmark], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Result {
                for bookmark in bookmarks {
                    try self.database.deleteBookmark(identifier: bookmark.identifier)
                    try self.pinboard.postsDelete(url: bookmark.url)
                }
            }
            completion(result)
        }
    }

    public func updateBookmarks(_ bookmarks: [Bookmark], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Result { () -> Void in
                for bookmark in bookmarks {
                    _ = try self.database.insertOrUpdateBookmark(bookmark)
                    let post = Pinboard.Post(bookmark)
                    try self.pinboard.postsAdd(post: post, replace: true)
                }
            }
            completion(result)
        }
    }

    public func renameTag(_ old: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Result {
                try self.pinboard.tagsRename(old, to: new)
                // TODO: Perform the changes locally.
                self.update(force: true)
            }
            completion(result)
        }
    }

    public func deleteTag(_ tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            let result = Result {
                try self.database.deleteTag(tag: tag)
                try self.pinboard.tagsDelete(tag)
                // TODO: Perform the changes locally.
                self.update(force: true)
            }
            completion(result)
        }
    }


}
