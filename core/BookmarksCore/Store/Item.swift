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
    public let toRead: Bool
    public let shared: Bool
    public let notes: String
    public let thumbnail: SafeImage?

    init(identifier: String,
         title: String,
         url: URL,
         tags: Set<String>,
         date: Date,
         toRead: Bool,
         shared: Bool,
         notes: String,
         thumbnail: SafeImage? = nil) {
        self.identifier = identifier
        self.title = title
        self.url = url
        self.tags = Set(tags.map { $0.lowercased() })
        self.date = date
        self.toRead = toRead
        self.shared = shared
        self.notes = notes
        self.thumbnail = thumbnail
    }

    public static func == (lhs: Item, rhs: Item) -> Bool {
        guard lhs.identifier == rhs.identifier else {
            return false
        }
        guard lhs.title == rhs.title else {
            return false
        }
        guard lhs.url == rhs.url else {
            return false
        }
        guard lhs.tags == rhs.tags else {
            return false
        }
        guard lhs.date == rhs.date else {
            return false
        }
        guard lhs.toRead == rhs.toRead else {
            return false
        }
        guard lhs.shared == rhs.shared else {
            return false
        }
        guard lhs.notes == rhs.notes else {
            return false
        }
        return true
    }

    public func setting(notes: String) -> Item {
        Item(identifier: identifier,
             title: title,
             url: url,
             tags: tags,
             date: date,
             toRead: toRead,
             shared: shared,
             notes: notes)
    }

}

extension Item: Identifiable {
    public var id: String { identifier }
}

extension Item: CustomStringConvertible {

    public var description: String { "\(url.absoluteString) (title: \(title), tags: [\(tags.joined(separator: ", "))], date: \(date), toRead: \(toRead), notes: '\(self.notes)')" }

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

// TODO: Move this elsewhere.
extension String {

    public func pinboardUrl(for user: String) throws -> URL {
        return try "https://pinboard.in/u:\(user)/t:\(self)/".asUrl()
    }

}
