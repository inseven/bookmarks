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

class Rainbow {

    var timer: Timer?

    init() {
        let iterator = UIColor.rainbowSequence(frequency: 0.05, amplitude: 55, center: 200, repeat: true).makeIterator()
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
            let color = iterator.next()!
            UIApplication.shared.windows.forEach { $0.tintColor = color }
        })
    }
}


@main
struct BookmarksApp: App {

    @Environment(\.manager) var manager: BookmarksManager
    @Environment(\.scenePhase) private var phase

    var rainbow = Rainbow()

    var body: some Scene {
        WindowGroup {
            ContentView(store: manager.store)
        }
        .onChange(of: phase) { phase in
            switch phase {
            case .active:
                manager.updater.start()
                #if targetEnvironment(macCatalyst)
                if let titlebar = UIApplication.shared.windows.first?.windowScene?.titlebar {
                    titlebar.titleVisibility = .hidden
                    titlebar.toolbar = nil
                }
                #endif
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
