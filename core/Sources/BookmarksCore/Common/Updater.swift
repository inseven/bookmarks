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

    func updater(_ updater: Updater, didProgress progress: Progress)

}

public class Updater {

    // TODO: ServiceState should be serializable and stored with each service instance.
    struct ServiceState {
        var token: String
        var lastUpdate: Date?
    }

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

    fileprivate func schedule(operation: RemoteOperation) {
        syncQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.syncQueue_perform(operation: operation)
        }
    }

    fileprivate func syncQueue_perform(operation: RemoteOperation) {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let progress = { (progress: Progress) in
            self.targetQueue.async {
                self.delegate?.updater(self, didProgress: progress)
            }
        }

        // Ensure we can get a log in token.
        guard let token = syncQueue_token() else {
            progress(.failure(BookmarksError.unauthorized))
            return
        }

        // Run the operation.
        // TODO: Work out how to make this cancellable.
        print("Running '\(operation.title)'....")
        let state = ServiceState(token: token, lastUpdate: lastUpdate)
        let result = Synchronize { [database] in
            try await operation.perform(database: database, state: state, progress: progress)
        }
        print("Finished '\(operation.title)'.")

        // Update the state in the case of success.
        if case .success(let success) = result {
            self.lastUpdate = success.lastUpdate
        }

        switch result {
        case .success(let success):
            self.lastUpdate = success.lastUpdate
            progress(.done(.now))
        case .failure(let error):
            progress(.failure(error))
        }

    }

    public func start() {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            timer = Timer.scheduledTimer(withTimeInterval: Self.updateTimeoutSeconds,
                                         repeats: true) { [weak self] timer in
                guard let self else {
                    return
                }
                self.schedule(operation: RefreshOperation(force: true))  // TODO: Should this really be forced?
            }
        }

        // TODO: Pull tasks off the queue.
    }

    // TODO: I wonder how this should even work. It feels like this is probably at the wrong point in the stack.
    public func authenticate(username: String,
                             password: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        Pinboard.apiToken(username: username, password: password) { result in
            self.syncQueue.sync {
                switch result {
                case .success(let token):
                    self.syncQueue_setToken(token)
                    self.refresh(force: true, completion: { _ in })  // Enqueue an initial update.
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

    public func refresh(force: Bool = false, completion: @escaping (Error?) -> Void = { _ in }) {
        schedule(operation: RefreshOperation(force: force))
        // TODO: Explore ways to ensure this completion corresponds with the requested update.
        DispatchQueue.global().async {
            completion(nil)
        }
    }

    public func delete(bookmarks: [Bookmark]) async throws {
        for bookmark in bookmarks {
            try await self.database.deleteBookmark(identifier: bookmark.identifier)
            schedule(operation: DeleteBookmark(bookmark: bookmark))
        }
    }

    public func update(bookmarks: [Bookmark]) async throws {
        for bookmark in bookmarks {
            _ = try await self.database.insertOrUpdateBookmark(bookmark)
            schedule(operation: UpdateBookmark(bookmark: bookmark))
        }
    }

    public func rename(tag: String, to newTag: String) async throws {
        // TODO: Perform the rename locally first.
        schedule(operation: RenameTag(tag: tag, newTag: newTag))
        schedule(operation: RefreshOperation(force: true))
    }

    public func delete(tags: [String]) async throws {
        for tag in tags {
            try await self.database.deleteTag(tag: tag)
            schedule(operation: DeleteTag(tag: tag))
        }
    }

}
