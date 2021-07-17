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
    public var updater: Updater
    public var pinboard: Pinboard

    public var database: Database

    // TODO: Maybe make the database store public instead?

    public init() {
        documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try! FileManager.default.createDirectory(at: documentsUrl, withIntermediateDirectories: true, attributes: nil)
        database = try! Database(path: documentsUrl.appendingPathComponent("store.db"))  // TODO: Handle this error?
        imageCache = FileImageCache(path: documentsUrl.appendingPathComponent("thumbnails"))
        downloadManager = DownloadManager(limit: settings.maximumConcurrentThumbnailDownloads)
        thumbnailManager = ThumbnailManager(imageCache: imageCache, downloadManager: downloadManager)
        updater = Updater(database: database, token: settings.pinboardApiKey)
        pinboard = Pinboard(token: settings.pinboardApiKey)  // TODO: Deal with token updates (don't require relaunch
        // TODO: Shared pinboard instance
        // TODO: Pinboard == updater == ?
        // TODO: Service == Pinboard + Updater? ServiceProtocol (talks Items)

        #if targetEnvironment(macCatalyst)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(nsApplicationDidBecomeActive),
                                       name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),
                                       object: nil)
        #endif

    }

    @objc
    func nsApplicationDidBecomeActive() {
        self.updater.start()
    }

}
