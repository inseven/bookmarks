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

    private var settings: Settings
    private var lastUpdate: Date? = nil  // Synchronized on syncQueue
    weak var delegate: UpdaterDelegate?

    private func syncQueue_token() -> String? {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        var token: String? = nil
        DispatchQueue.main.sync {
            token = settings.pinboardApiKey
        }
        return token
    }

    private func syncQueue_setToken(_ token: String?) {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        DispatchQueue.main.sync {
            settings.pinboardApiKey = token
        }
    }

    public init(database: Database, settings: Settings) {
        self.database = database
        self.settings = settings
    }

    func performUpdate(update: @escaping (Pinboard) throws -> Void) {
        syncQueue.async {
            self.targetQueue.async {
                self.delegate?.updaterDidStart(self)
            }
            do {
                guard let token = self.syncQueue_token() else {
                    throw BookmarksError.unauthorized
                }
                let pinboard = Pinboard(token: token)
                try update(pinboard)
                self.targetQueue.async {
                    self.delegate?.updaterDidFinish(self)
                }
            } catch {
                print("Failed to update post with error \(error).")
                self.targetQueue.async {
                    self.delegate?.updater(self, didFailWithError: BookmarksError.unauthorized)
                }
            }
        }
    }

    fileprivate func syncQueue_update(force: Bool) {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        print("updating...")
        targetQueue.async {
            self.delegate?.updaterDidStart(self)
        }

        guard let token = syncQueue_token() else {
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
                targetQueue.async {
                    self.delegate?.updaterDidFinish(self)
                }
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
                let bookmark = try self.database.bookmarkSync(identifier: identifier)
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

    public func authenticate(username: String,
                             password: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        Pinboard.apiToken(username: username, password: password) { result in
            self.syncQueue.sync {
                switch result {
                case .success(let token):
                    self.syncQueue_setToken(token)
                    self.update(force: true)  // Enqueue an initial update.
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        syncQueue.async {
            // TODO: Cancel any ongoing sync.
            self.syncQueue_setToken(nil)
            self.lastUpdate = nil
            self.database.clear(completion: completion)
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
            guard let token = self.syncQueue_token() else {
                completion(.failure(BookmarksError.unauthorized))
                return
            }
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
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        for bookmark in bookmarks {
            do {
                _ = try self.database.insertOrUpdateBookmark(bookmark)
                performUpdate { pinboard in
                    let post = Pinboard.Post(bookmark)
                    try pinboard.postsAdd(post: post, replace: true)
                }
            } catch {
                completion(.failure(error))
                return
            }
        }
        completion(.success(()))
    }

    public func renameTag(_ old: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        syncQueue.async {
            guard let token = self.syncQueue_token() else {
                completion(.failure(BookmarksError.unauthorized))
                return
            }
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
        syncQueue.async {
            guard let token = self.syncQueue_token() else {
                completion(.failure(BookmarksError.unauthorized))
                return
            }
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
