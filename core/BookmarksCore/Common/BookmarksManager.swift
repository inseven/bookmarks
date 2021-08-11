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

import Combine
import SwiftUI

public struct ManagerEnvironmentKey: EnvironmentKey {
    public static var defaultValue = BookmarksManager()
}

public extension EnvironmentValues {
    var manager: BookmarksManager {
        get { self[ManagerEnvironmentKey.self] }
        set { self[ManagerEnvironmentKey.self] = newValue }
    }
}

// TODO: Explore whether it's possible make some of the BookmarksManager properties private #266
//       https://github.com/inseven/bookmarks/issues/266
public class BookmarksManager {

    var documentsUrl: URL
    public var imageCache: ImageCache!
    public var thumbnailManager: ThumbnailManager
    var downloadManager: DownloadManager
    public var settings = Settings()
    fileprivate var updater: Updater
    fileprivate var pinboard: Pinboard

    public var tagsView: TagsView

    public var cache: NSCache = NSCache<NSString, SafeImage>()

    public var database: Database

    public init() {
        documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try! FileManager.default.createDirectory(at: documentsUrl, withIntermediateDirectories: true, attributes: nil)
        // TODO: Handle database initialisation errors #143
        //       https://github.com/inseven/bookmarks/issues/143
        database = try! Database(path: documentsUrl.appendingPathComponent("store.db"))
        imageCache = FileImageCache(path: documentsUrl.appendingPathComponent("thumbnails"))
        downloadManager = DownloadManager(limit: settings.maximumConcurrentThumbnailDownloads)
        thumbnailManager = ThumbnailManager(imageCache: imageCache, downloadManager: downloadManager)
        pinboard = Pinboard(token: settings.pinboardApiKey)
        updater = Updater(database: database, pinboard: pinboard)
        updater.start()

        tagsView = TagsView(database: database)
        tagsView.start()

        #if os(macOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(nsApplicationDidBecomeActive),
                                       name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),
                                       object: nil)
        #endif
    }

    public var user: String? {
        settings.pinboardApiKey.components(separatedBy: ":").first
    }

    public func refresh(force: Bool = false) {
        self.updater.update(force: force)
    }

    // TODO: Move the Bookmark update APIs into the updater #237
    //       https://github.com/inseven/bookmarks/issues/237

    public func deleteItem(_ item: Item, completion: @escaping (Result<Void, Error>) -> Void) {
        updater.deleteItem(item, completion: completion)
    }

    public func updateItem(_ item: Item, completion: @escaping (Result<Item, Error>) -> Void) {
        self.updater.updateItem(item: item, completion: completion)
    }

    public func renameTag(_ old: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.updater.renameTag(old, to: new, completion: completion)
    }

    public func deleteTag(_ tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.updater.deleteTag(tag, completion: completion)
    }

    public func open(items: [Item], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.main.asyncClosure(completion)
        let many = open(urls: items.map { $0.url })
        _ = many.sink { result in
            switch result {
            case .finished:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        } receiveValue: { _ in }
    }

    public func openOnInternetArchive(items: [Item], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.main.asyncClosure(completion)
        do {
            let many = open(urls: try items.map { try $0.internetArchiveUrl() })
            _ = many.sink { result in
                switch result {
                case .finished:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in }
        } catch {
            completion(.failure(error))
        }
    }

    public func editOnPinboard(items: [Item], completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.main.asyncClosure(completion)
        do {
            let many = open(urls: try items.map { try $0.pinboardUrl() })
            _ = many.sink { result in
                switch result {
                case .finished:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in }
        } catch {
            completion(.failure(error))
        }
    }

    fileprivate func open(urls: [URL]) -> Publishers.MergeMany<Future<Void, Error>> {
        let openers = urls.map { self.open(url: $0) }
        let many = Publishers.MergeMany(openers)
        return many
    }

    fileprivate func open(url: URL) -> Future<Void, Error> {
        return Future() { promise in
            self.open(url: url) { success in
                if success {
                    promise(.success(()))
                } else {
                    promise(.failure(BookmarksError.openFailure))
                }
            }
        }
    }

    fileprivate func open(url: URL, completion: @escaping (Bool) -> Void) {
        let completion = DispatchQueue.main.asyncClosure(completion)
        #if os(macOS)
        NSWorkspace.shared.open(url)
        completion(true)
        #else
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
        #endif
    }

    @objc
    func nsApplicationDidBecomeActive() {
        self.updater.update()
    }

}
