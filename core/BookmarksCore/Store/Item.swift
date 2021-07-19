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

#if os(iOS)
import UIKit
#endif

public class Item: Equatable {

    public let identifier: String
    public let title: String
    public let url: URL
    public let tags: Set<String>
    public let date: Date
    public let thumbnail: Image?

    init(identifier: String, title: String, url: URL, tags: Set<String>, date: Date, thumbnail: Image? = nil) {
        self.identifier = identifier
        self.title = title
        self.url = url
        self.tags = Set(tags.map { $0.lowercased() })
        self.date = date
        self.thumbnail = thumbnail
    }

    public static var supportsSecureCoding: Bool { true }

    static let identifierKey = "identifier"
    static let titleKey = "title"
    static let urlKey = "url"
    static let tagsKey = "tags"
    static let dateKey = "date"

    public static func == (lhs: Item, rhs: Item) -> Bool {
        return
            lhs.identifier == rhs.identifier &&
            lhs.title == rhs.title &&
            lhs.url == rhs.url &&
            lhs.tags == rhs.tags &&
            lhs.date == rhs.date
    }

}

extension Item: Identifiable {
    public var id: String { identifier }
}

extension Item: CustomStringConvertible {

    public var description: String { "\(self.url.absoluteString) (\(self.title))" }

}

extension Item {

    // TODO: Update to throwing properties when adopting Swift 5.5 #142
     //       https://github.com/inseven/bookmarks/issues/142
    public func internetArchiveUrl() throws -> URL {
        try "https://web.archive.org/web/*/".asUrl().appendingPathComponent(url.absoluteString)
    }

    // TODO: Update to throwing properties when adopting Swift 5.5 #142
     //       https://github.com/inseven/bookmarks/issues/142
    public func pinboardUrl() throws -> URL {
         try "https://pinboard.in/add".asUrl().settingQueryItems([
            URLQueryItem(name: "url", value: url.absoluteString)
        ])
    }

}
