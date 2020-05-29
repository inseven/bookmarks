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
}

final class Settings: ObservableObject {

    @Published var pinboardApiKey: String {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(pinboardApiKey, forKey: SettingsKey.pinboardApiKey.rawValue)
            defaults.synchronize()
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.pinboardApiKey = defaults.string(forKey: SettingsKey.pinboardApiKey.rawValue) ?? ""
    }

}
