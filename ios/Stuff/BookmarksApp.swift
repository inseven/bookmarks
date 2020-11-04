//
//  BookmarksApp.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 03/11/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

struct ManagerEnvironmentKey: EnvironmentKey {
    static var defaultValue = BookmarksManager()
}

extension EnvironmentValues {
    var manager: BookmarksManager {
        get { self[ManagerEnvironmentKey.self] }
        set { self[ManagerEnvironmentKey.self] = newValue }
    }
}


class BookmarksManager {

    var documentsUrl: URL
    var store: Store
    var imageCache: ImageCache!
    var thumbnailManager: ThumbnailManager
    var downloadManager: DownloadManager
    var settings = Settings()
    var updater: Updater

    init() {
        documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try! FileManager.default.createDirectory(at: documentsUrl, withIntermediateDirectories: true, attributes: nil)
        store = Store(path: documentsUrl.appendingPathComponent("store.plist"), targetQueue: .main)
        imageCache = FileImageCache(path: documentsUrl.appendingPathComponent("thumbnails"))
        downloadManager = DownloadManager(limit: settings.maximumConcurrentThumbnailDownloads)
        thumbnailManager = ThumbnailManager(imageCache: imageCache, downloadManager: downloadManager)
        updater = Updater(store: store, token: settings.pinboardApiKey)
    }

}


@main
struct BookmarksApp: App {

    @Environment(\.manager) var manager: BookmarksManager
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView(store: manager.store)
        }
        .onChange(of: phase) { phase in
            switch phase {
            case .active:
                manager.updater.start()
            case .background:
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
