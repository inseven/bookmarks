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

import Combine
import SwiftUI

import Interact

public struct ManagerEnvironmentKey: EnvironmentKey {
    public static var defaultValue = BookmarksManager()
}

public extension EnvironmentValues {
    var manager: BookmarksManager {
        get { self[ManagerEnvironmentKey.self] }
        set { self[ManagerEnvironmentKey.self] = newValue }
    }
}

public class BookmarksManager: ObservableObject {

    public enum State {
        case idle
        case unauthorized
    }

    @Published public var state: State = .idle

    // TODO: Explore whether it's possible make some of the BookmarksManager properties private #266
    //       https://github.com/inseven/bookmarks/issues/266
    public var imageCache: ImageCache!
    public var thumbnailManager: ThumbnailManager
    public var settings = Settings()
    public var tagsView: TagsView
    public var cache: NSCache = NSCache<NSString, SafeImage>()
    public var database: Database

    private var documentsUrl: URL
    private var downloadManager: DownloadManager
    private var updater: Updater

    public init() {
        documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try! FileManager.default.createDirectory(at: documentsUrl, withIntermediateDirectories: true, attributes: nil)
        // TODO: Handle database initialisation errors #143
        //       https://github.com/inseven/bookmarks/issues/143
        database = try! Database(path: documentsUrl.appendingPathComponent("store.db"))
        imageCache = FileImageCache(path: documentsUrl.appendingPathComponent("thumbnails"))
        downloadManager = DownloadManager(limit: settings.maximumConcurrentThumbnailDownloads)
        thumbnailManager = ThumbnailManager(imageCache: imageCache, downloadManager: downloadManager)
        updater = Updater(database: database, settings: settings)
        tagsView = TagsView(database: database)

        updater.delegate = self
        updater.start()
        tagsView.start()

        #if os(macOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(nsApplicationDidBecomeActive),
                                       name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),
                                       object: nil)
        #endif
    }

    public var user: String? {
        return updater.user
    }

    public func authenticate(username: String,
                             password: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        updater.authenticate(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.state = .idle
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        let completion = DispatchQueue.global().asyncClosure(completion)
        updater.logout { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.state = .unauthorized
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func refresh() {
        updater.update(force: true)
    }

    public func deleteBookmarks(_ bookmarks: [Bookmark], completion: @escaping (Result<Void, Error>) -> Void) {
        updater.deleteBookmarks(bookmarks, completion: completion)
    }

    public func deleteBookmarks(_ bookmarks: Set<Bookmark>, completion: @escaping (Result<Void, Error>) -> Void) {
        updater.deleteBookmarks(Array(bookmarks), completion: completion)
    }
    
    public func deleteBookmarks(_ bookmarks: [Bookmark]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            updater.deleteBookmarks(bookmarks) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func updateBookmarks(_ bookmarks: [Bookmark], completion: @escaping (Result<Void, Error>) -> Void) {
        updater.updateBookmarks(bookmarks, completion: completion)
    }

    public func updateBookmarks(_ bookmarks: Set<Bookmark>, completion: @escaping (Result<Void, Error>) -> Void) {
        updater.updateBookmarks(Array(bookmarks), completion: completion)
    }
    
    public func updateBookmarks(_ bookmarks: [Bookmark]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            updater.updateBookmarks(bookmarks) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func renameTag(_ old: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updater.renameTag(old, to: new, completion: completion)
    }

    public func deleteTag(_ tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updater.deleteTag(tag, completion: completion)
    }

    @MainActor public func open(_ bookmarks: Set<Bookmark>,
                                location: Bookmark.Location = .web) {
        open(Array(bookmarks), location: location)
    }

    @MainActor public func open(_ bookmarks: [Bookmark], location: Bookmark.Location = .web) {
        do {
            for url in try bookmarks.map({ try $0.url(location) }) {
                Application.open(url)
            }
        } catch {
            print("Failed to open bookmarks with error \(error)")
        }
    }

    @objc func nsApplicationDidBecomeActive() {
        self.updater.update()
    }

}

extension BookmarksManager: UpdaterDelegate {

    func updaterDidStart(_ updater: Updater) {
    }

    func updaterDidFinish(_ updater: Updater) {
    }

    func updater(_ updater: Updater, didFailWithError error: Error) {
        print("Failed to update bookmarks with error \(error)")
        switch error {
        case BookmarksError.httpError(.unauthorized), BookmarksError.unauthorized:
            DispatchQueue.main.async {
                self.state = .unauthorized
            }
        default:
            print("Ignoring error \(error)...")
        }
    }

}
