//
//  Settings.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation

enum SettingsKey: String {
    case pinboardApiKey = "pinboard-api-key"
    case useInAppBrowser = "use-in-app-browser"
    case maximumConcurrentThumbnailDownloads = "maximum-concurrent-thumbnail-downloads"
}

final class Settings: ObservableObject {

    var defaults: UserDefaults {
        UserDefaults.standard
    }

    @Published var pinboardApiKey: String {
        didSet { defaults.set(pinboardApiKey, forKey: SettingsKey.pinboardApiKey.rawValue) }
    }

    @Published var useInAppBrowser: Bool {
        didSet { defaults.set(useInAppBrowser, forKey: SettingsKey.useInAppBrowser.rawValue) }
    }

    @Published var maximumConcurrentThumbnailDownloads: Int {
        didSet { defaults.set(maximumConcurrentThumbnailDownloads,
                              forKey: SettingsKey.maximumConcurrentThumbnailDownloads.rawValue) }
    }

    init() {
        let defaults = UserDefaults.standard
        pinboardApiKey = defaults.string(forKey: SettingsKey.pinboardApiKey.rawValue) ?? ""
        useInAppBrowser = defaults.bool(forKey: SettingsKey.useInAppBrowser.rawValue)
        maximumConcurrentThumbnailDownloads = defaults.integer(forKey: SettingsKey.maximumConcurrentThumbnailDownloads.rawValue)
        if maximumConcurrentThumbnailDownloads == 0 {
            maximumConcurrentThumbnailDownloads = 3
        }
    }

}
