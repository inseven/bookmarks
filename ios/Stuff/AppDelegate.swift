//
//  AppDelegate.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }

    lazy var documentsDirectory: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }()

    lazy var store: Store! = {
        return Store(path: documentsDirectory.appendingPathComponent("store.plist"), targetQueue: .main)
    }()

    // TODO: Consider lazy variables.
    var window: UIWindow?
    var updater: Updater!
    var imageCache: ImageCache!
    var thumbnailManager: ThumbnailManager!
    var downloadManager: DownloadManager!
    var settings = Settings()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        updater = Updater(store: store, token: settings.pinboardApiKey)
        imageCache = FileImageCache(path: documentsDirectory.appendingPathComponent("thumbnails"))
//        imageCache = MemoryImageCache()
        downloadManager = DownloadManager(limit: settings.maximumConcurrentThumbnailDownloads)
        thumbnailManager = ThumbnailManager(imageCache: imageCache, downloadManager: downloadManager)
        updater.start()

        #if targetEnvironment(macCatalyst)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(nsApplicationDidBecomeActive),
                                       name: NSNotification.Name("NSApplicationDidBecomeActiveNotification"),
                                       object: nil)
        #endif

        return true
    }

    @objc
    func nsApplicationDidBecomeActive() {
        self.updater.start()
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        self.updater.start()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == UIMenuSystem.main else { return }
        let find = UIKeyCommand(title: "Find", image: nil, action: #selector(ViewController.findShortcut), input: "f", modifierFlags: [.command])
        let newMenu = UIMenu(title: "File", options: .displayInline, children: [find])
        builder.insertChild(newMenu, atStartOfMenu: .file)
    }

}

