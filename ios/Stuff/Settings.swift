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
}

final class Settings: ObservableObject {

    var defaults: UserDefaults {
        UserDefaults.standard
    }

    @Published var pinboardApiKey: String {
        didSet {
            defaults.set(pinboardApiKey, forKey: SettingsKey.pinboardApiKey.rawValue)
            defaults.synchronize()
        }
    }

    @Published var useInAppBrowser: Bool {
        didSet {
            defaults.set(useInAppBrowser, forKey: SettingsKey.useInAppBrowser.rawValue)
            defaults.synchronize()
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.pinboardApiKey = defaults.string(forKey: SettingsKey.pinboardApiKey.rawValue) ?? ""
        self.useInAppBrowser = defaults.bool(forKey: SettingsKey.useInAppBrowser.rawValue)
    }

}
