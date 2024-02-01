// Copyright (c) 2020-2024 InSeven Limited
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

public enum SettingsKey: RawRepresentable {

    case pinboardApiKey
    case useInAppBrowser
    case maximumConcurrentThumbnailDownloads
    case favoriteTags
    case addTagsMarkAsRead
    case layoutMode(BookmarksSection)
    case topTagsCount
    case showSectionCounts
    case librarySections

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
        case "top-tags-count":
            self = .topTagsCount
        case "show-section-counts":
            self = .showSectionCounts
        case "library-sections":
            self = .librarySections
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
        case .topTagsCount:
            return "top-tags-count"
        case .showSectionCounts:
            return "show-section-counts"
        case .layoutMode(let section):
            return "\(Self.layoutModePrefix)\(section.rawValue)"
        case .librarySections:
            return "library-sections"
        }
    }
}
