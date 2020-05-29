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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create documents directory with error \(error)")
        }
        store = Store(path: documentsDirectory.appendingPathComponent("store.plist"), targetQueue: .main)
        updater = Updater(store: store, token: "jbmorley:08f37da5d082080ae1a5")
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

}

