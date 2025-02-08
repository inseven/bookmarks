// Copyright (c) 2020-2025 Jason Morley
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

import SwiftUI

import Interact

struct SceneState: Codable, RawRepresentable {

    public enum SheetType: Identifiable, Codable {

        public var id: String {
            switch self {
            case .tags:
                return "tags"
            case .settings:
                return "settings"
            case .edit(let id):
                return "edit-\(id)"
            }
        }

        case tags
        case settings
        case edit(Bookmark.ID)
    }

    enum CodingKeys: String, CodingKey {
        case section
        case sheet
        case previewURL
    }

    var section: BookmarksSection? = .all
    var sheet: SheetType? = nil
    var previewURL: URL? = nil

    init() {

    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        section = try container.decodeIfPresent(BookmarksSection.self, forKey: .section)
        sheet = try container.decodeIfPresent(SheetType.self, forKey: .sheet)
        previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(section, forKey: .section)
        try container.encodeIfPresent(sheet, forKey: .sheet)
        try container.encodeIfPresent(previewURL, forKey: .previewURL)
    }

    init?(rawValue: String) {
      guard let data = rawValue.data(using: .utf8),
        let result = try? JSONDecoder().decode(Self.self, from: data)
      else {
        return nil
      }
      self = result
    }

    var rawValue: String {
      guard let data = try? JSONEncoder().encode(self),
            let string = String(data: data, encoding: .utf8)
      else {
        return "{}"
      }
      return string
    }

    mutating func showTags() {
        sheet = .tags
    }

    mutating func showSettings() {
        sheet = .settings
    }

    mutating func edit(_ bookmark: Bookmark) {
        sheet = .edit(bookmark.id)
    }

    mutating func showURL(_ url: URL, browser: BrowserPreference) {
        switch browser {
        case .app:
            previewURL = url
        case .system:
            Application.open(url)
        }
    }

    mutating func revealTag(_ tag: String) {
        sheet = nil
        section = .tag(tag)
    }

    mutating func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        switch url.scheme {
        case URL.actionScheme:
            switch url.pathComponents {
            case ["/", "show"]:
                guard let tag = components.queryItem("tag") else {
                    return
                }
                revealTag(tag)
            default:
                break
            }
        default:
            print("Failed to open unsupported URL '\(url.absoluteString)'.")
        }
    }

}

struct FocusedSceneStateValueKey: FocusedValueKey {
    typealias Value = Binding<SceneState>
}

extension FocusedValues {

    var sceneState: FocusedSceneStateValueKey.Value? {
        get { self[FocusedSceneStateValueKey.self] }
        set { self[FocusedSceneStateValueKey.self] = newValue }
    }

}
