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

final public class Settings: ObservableObject {

    public enum ShowSectionCount: String, CaseIterable, Identifiable {

        public var id: Self {
            return self
        }

        case never
        case unread
        case all
    }

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

    @Published public var topTagsCount: Int {
        didSet {
            defaults.set(topTagsCount, forKey: .topTagsCount)
        }
    }

    @Published public var showSectionCounts: ShowSectionCount {
        didSet {
            defaults.set(showSectionCounts, forKey: .showSectionCounts)
        }
    }

    public var user: String? {
        return pinboardApiKey?.components(separatedBy: ":").first
    }

    public init() {
        pinboardApiKey = defaults.string(forKey: .pinboardApiKey) ?? ""
        useInAppBrowser = defaults.bool(forKey: .useInAppBrowser)
        maximumConcurrentThumbnailDownloads = defaults.integer(forKey: .maximumConcurrentThumbnailDownloads, default: 3)
        favoriteTags = defaults.object(forKey: .favoriteTags) as? [String] ?? []
        topTagsCount = defaults.integer(forKey: .topTagsCount, default: 5)
        showSectionCounts = defaults.value(forKey: .showSectionCounts, default: .unread)
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
