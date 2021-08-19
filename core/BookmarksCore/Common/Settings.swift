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

import Foundation

public enum SettingsKey: String {
    case pinboardApiKey = "pinboard-api-key"
    case useInAppBrowser = "use-in-app-browser"
    case maximumConcurrentThumbnailDownloads = "maximum-concurrent-thumbnail-downloads"
    case favoriteTags = "favorite-tags"
    case addTagsMarkAsRead = "add-tags-mark-as-read"
}

final public class Settings: ObservableObject {

    var defaults: UserDefaults {
        UserDefaults.standard
    }

    @Published public var pinboardApiKey: String {
        didSet { defaults.set(pinboardApiKey, forKey: SettingsKey.pinboardApiKey.rawValue) }
    }

    @Published public var useInAppBrowser: Bool {
        didSet { defaults.set(useInAppBrowser, forKey: SettingsKey.useInAppBrowser.rawValue) }
    }

    @Published public var maximumConcurrentThumbnailDownloads: Int {
        didSet { defaults.set(maximumConcurrentThumbnailDownloads,
                              forKey: SettingsKey.maximumConcurrentThumbnailDownloads.rawValue) }
    }

    @Published public var favoriteTags: [String] {
        didSet { defaults.set(favoriteTags,
                              forKey: SettingsKey.favoriteTags.rawValue) }
    }

    public init() {
        let defaults = UserDefaults.standard
        pinboardApiKey = defaults.string(forKey: SettingsKey.pinboardApiKey.rawValue) ?? ""
        useInAppBrowser = defaults.bool(forKey: SettingsKey.useInAppBrowser.rawValue)
        maximumConcurrentThumbnailDownloads = defaults.integer(forKey: SettingsKey.maximumConcurrentThumbnailDownloads.rawValue)
        favoriteTags = defaults.object(forKey: SettingsKey.favoriteTags.rawValue) as? [String] ?? []
        if maximumConcurrentThumbnailDownloads == 0 {
            maximumConcurrentThumbnailDownloads = 3
        }
    }

}
