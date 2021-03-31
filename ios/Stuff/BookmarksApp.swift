// Copyright (c) 2020-2021 Jason Barrie Morley
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

//    var rainbow = Rainbow()

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
