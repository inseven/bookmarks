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

public class BookmarksManager {

    var documentsUrl: URL
    public var imageCache: ImageCache!
    public var thumbnailManager: ThumbnailManager
    var downloadManager: DownloadManager
    public var settings = Settings()
    fileprivate var updater: Updater
    fileprivate var pinboard: Pinboard

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

    public func refresh() {
        self.updater.update()
    }

    // TODO: Move the Bookmark update APIs into the updater #237
    //       https://github.com/inseven/bookmarks/issues/237

    public func deleteItem(item: Item, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.database.deleteItem(identifier: item.identifier)
                try self.pinboard.postsDelete(url: item.url)
            }
            completion(result)
        }
    }

    public func updateItem(item: Item, completion: @escaping (Result<Item, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> Item in
                let item = try self.database.insertOrUpdate(item: item)
                let post = Pinboard.Post(item: item)
                try self.pinboard.postsAdd(post: post, replace: true)
                self.updater.update()
                return item
            }
            completion(result)
        }
    }

    public func renameTag(_ old: String, to new: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.pinboard.tagsRename(old, to: new)
                self.refresh()
            }
            completion(result)
        }
    }

    public func deleteTag(tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global(qos: .userInitiated).asyncClosure(completion)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.database.deleteTag(tag: tag)
                try self.pinboard.tagsDelete(tag)
                self.refresh()
            }
            completion(result)
        }
    }

    @objc
    func nsApplicationDidBecomeActive() {
        self.updater.update()
    }

}
