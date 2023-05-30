// Copyright (c) 2020-2023 InSeven Limited
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

import Interact

public enum SettingsKey: RawRepresentable {

    case pinboardApiKey
    case useInAppBrowser
    case maximumConcurrentThumbnailDownloads
    case favoriteTags
    case addTagsMarkAsRead
    case layoutMode(BookmarksSection)

    static let layoutModePrefix = "layout-mode-"

    public init?(rawValue: String) {
        switch rawValue {
        case "pinboard-api-key":
            self = .pinboardApiKey
        case "use-in-app-browser":
            self = .useInAppBrowser
        case "maximum-concurrent-thumbnail-downloads":
            self = .maximumConcurrentThumbnailDownloads
        case "favorite-tags":
            self = .favoriteTags
        case "add-tags-mark-as-read":
            self = .addTagsMarkAsRead
        case _ where rawValue.starts(with: Self.layoutModePrefix):
            let rawSection = String(rawValue.dropFirst(Self.layoutModePrefix.count))
            guard let section = BookmarksSection(rawValue: rawSection) else {
                return nil
            }
            self = .layoutMode(section)
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .pinboardApiKey:
            return "pinboard-api-key"
        case .useInAppBrowser:
            return "use-in-app-browser"
        case .maximumConcurrentThumbnailDownloads:
            return "maximum-concurrent-thumbnail-downloads"
        case .favoriteTags:
            return "favorite-tags"
        case .addTagsMarkAsRead:
            return "add-tags-mark-as-read"
        case .layoutMode(let section):
            return "\(Self.layoutModePrefix)\(section.rawValue)"
        }
    }
}

final public class Settings: ObservableObject {

    let defaults = KeyedDefaults<SettingsKey>(defaults: UserDefaults(suiteName: "group.uk.co.inseven.bookmarks")!)

    @Published public var pinboardApiKey: String? {
        didSet {
            defaults.set(pinboardApiKey, forKey: .pinboardApiKey)
        }
    }

    @Published public var useInAppBrowser: Bool {
        didSet {
            defaults.set(useInAppBrowser, forKey: .useInAppBrowser)
        }
    }

    @Published public var maximumConcurrentThumbnailDownloads: Int {
        didSet {
            defaults.set(maximumConcurrentThumbnailDownloads, forKey: .maximumConcurrentThumbnailDownloads)
        }
    }

    @Published public var favoriteTags: [String] {
        didSet {
            defaults.set(favoriteTags, forKey: .favoriteTags)
        }
    }

    public init() {
        pinboardApiKey = defaults.string(forKey: .pinboardApiKey) ?? ""
        useInAppBrowser = defaults.bool(forKey: .useInAppBrowser)
        maximumConcurrentThumbnailDownloads = defaults.integer(forKey: .maximumConcurrentThumbnailDownloads)
        favoriteTags = defaults.object(forKey: .favoriteTags) as? [String] ?? []
        if maximumConcurrentThumbnailDownloads == 0 {
            maximumConcurrentThumbnailDownloads = 3
        }
    }

    public func layoutMode(for section: BookmarksSection) -> LayoutMode {
        guard let rawLayoutMode = defaults.string(forKey: .layoutMode(section)),
              let layoutMode = LayoutMode(rawValue: rawLayoutMode) else {
            return .grid
        }
        return layoutMode
    }

    public func setLayoutMode(_ layoutMode: LayoutMode, for section: BookmarksSection) {
        defaults.set(layoutMode.rawValue, forKey: .layoutMode(section))
    }

}
