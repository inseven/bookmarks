//
//  AppDelegate.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import UIKit

// TODO: Debug button to clear the image cache.

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // TODO: Consider lazy variables.
    var window: UIWindow?
    var store: Store!
    var updater: Updater!
    var imageCache: ImageCache!
    var thumbnailManager: ThumbnailManager!
    var settings = Settings()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create documents directory with error \(error)")
        }
        store = Store(path: documentsDirectory.appendingPathComponent("store.plist"), targetQueue: .main)
        updater = Updater(store: store, token: settings.pinboardApiKey)
        imageCache = FileImageCache(path: documentsDirectory.appendingPathComponent("thumbnails"))
//        imageCache = MemoryImageCache()
        thumbnailManager = ThumbnailManager(imageCache: imageCache)
        updater.start()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
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

