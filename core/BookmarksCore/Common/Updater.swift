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

protocol UpdaterDelegate: AnyObject {

    func updaterDidStart(_ updater: Updater)
    func updaterDidFinish(_ updater: Updater)
    func updater(_ updater: Updater, didFailWithError error: Error)

}

public class Updater {

    static var updateTimeoutSeconds = 5 * 60.0

    private let syncQueue = DispatchQueue(label: "Updater.syncQueue")
    private let targetQueue = DispatchQueue(label: "Updater.targetQueue")
    private let database: Database
    private var timer: Timer?

    private var token: String? // Synchronized on syncQueue
    private var lastUpdate: Date? = nil  // Synchronized on syncQueue
    weak var delegate: UpdaterDelegate?

    public var user: String? {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        var user: String? = nil
        syncQueue.sync {
            user = self.token?.components(separatedBy: ":").first
        }
        return user
    }

    public init(database: Database, token: String?) {
        self.database = database
        self.token = token
    }

    fileprivate func syncQueue_update(force: Bool) {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        print("updating...")
        targetQueue.async {
            self.delegate?.updaterDidStart(self)
        }

        guard let token = token else {
            targetQueue.async {
                self.delegate?.updater(self, didFailWithError: BookmarksError.unauthorized)
            }
            return
        }

        do {

            // Check to see when the bookmarks were last updated and don't update if there are no new changes.
            let pinboard = Pinboard(token: token)
            let update = try pinboard.postsUpdate()
            if let lastUpdate = self.lastUpdate,
               lastUpdate >= update.updateTime,
               !force {
                print("skipping empty update")
                return
            }

            // Get the posts.
            let posts = try pinboard.postsAll()

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

            targetQueue.async {
                self.delegate?.updaterDidFinish(self)
            }

        } catch {
            targetQueue.async {
                self.delegate?.updater(self, didFailWithError: error)
            }
        }
    }

    public func start() {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            timer = Timer.scheduledTimer(withTimeInterval: Self.updateTimeoutSeconds,
                                         repeats: true) { [weak self] timer in
                guard let self = self else {
                    return
                }
                self.syncQueue.async {
                    self.syncQueue_update(force: true)
                }
            }
        }
    }

    public func set(token: String) {
        syncQueue.async {
            self.token = token
            self.syncQueue_update(force: true)  // TODO: Do I want to do this?
        }
    }

    public func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            self.token = nil
            // TODO: Cancel any ongoing sync.
            // TODO: Handle the error?
            self.database.clear { result in
                print("result = \(result)")
                completion(result)
            }
            // TODO: Right now this has the side effect of changing the top-level state but we should do it ourselves.
//            self.syncQueue_update(force: true)  // TODO: Do I want to do this?
            // TODO: Empty the database.
            // TODO: This should clear the last updated?
            // TODO: Would it be cleaner to store all state in a single variable so it can be cleared out / easily serialized?
        }
    }

    public func update(force: Bool = false) {
        syncQueue.async {
            self.syncQueue_update(force: force)
            // TODO: Delete everything.
            self.syncQueue_update(force: true)
        }
    }

    public func deleteBookmarks(_ bookmarks: [Bookmark], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        guard let token = token else {
            completion(.failure(BookmarksError.unauthorized))
            return
        }
        syncQueue.async {
            let pinboard = Pinboard(token: token)
            let result = Result {
                for bookmark in bookmarks {
                    try self.database.deleteBookmark(identifier: bookmark.identifier)
                    try pinboard.postsDelete(url: bookmark.url)
                }
            }
            completion(result)
        }
    }

    public func updateBookmarks(_ bookmarks: [Bookmark], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        guard let token = token else {
            completion(.failure(BookmarksError.unauthorized))
            return
        }
        syncQueue.async {
            let pinboard = Pinboard(token: token)
            let result = Result { () -> Void in
                for bookmark in bookmarks {
                    _ = try self.database.insertOrUpdateBookmark(bookmark)
                    let post = Pinboard.Post(bookmark)
                    try pinboard.postsAdd(post: post, replace: true)
                }
            }
            completion(result)
        }
    }

    public func renameTag(_ old: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        guard let token = token else {
            completion(.failure(BookmarksError.unauthorized))
            return
        }
        syncQueue.async {
            let pinboard = Pinboard(token: token)
            let result = Result {
                try pinboard.tagsRename(old, to: new)
                // TODO: Perform the changes locally.
                self.update(force: true)
            }
            completion(result)
        }
    }

    public func deleteTag(_ tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        guard let token = token else {
            completion(.failure(BookmarksError.unauthorized))
            return
        }
        syncQueue.async {
            let pinboard = Pinboard(token: token)
            let result = Result {
                try self.database.deleteTag(tag: tag)
                try pinboard.tagsDelete(tag)
                // TODO: Perform the changes locally.
                self.update(force: true)
            }
            completion(result)
        }
    }


}
