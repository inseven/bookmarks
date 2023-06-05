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

import Combine
import SwiftUI

public class SceneModel: ObservableObject {

    public enum SheetType: Identifiable {

        public var id: String {
            switch self {
            case .tags:
                return "tags"
            case .settings:
                return "settings"
            case .edit(let bookmark):
                return "edit-\(bookmark.id)"
            }
        }

        case tags
        case settings
        case edit(Bookmark)
    }

    var settings: Settings

    @Published public var section: BookmarksSection? = .all
    @Published public var sheet: SheetType? = nil

    public init(settings: Settings) {
        self.settings = settings
    }

    @MainActor public func showTags() {
        sheet = .tags
    }

    @MainActor public func showSettings() {
        sheet = .settings
    }

    @MainActor public func edit(_ bookmark: Bookmark) {
        sheet = .edit(bookmark)
    }

    @MainActor public func revealTag(_ tag: String) {
        sheet = nil
        section = .tag(tag)
    }

    @MainActor public func handleURL(_ url: URL) {
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
