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

public class Bookmark: Equatable {

    public enum Location {
        case web
        case internetArchive
        case pinboard
    }

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

    public static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
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
    
    public func setting(title: String) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: tags,
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func setting(notes: String) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: tags,
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func setting(tags: Set<String>) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: tags,
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func setting(toRead: Bool) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: tags,
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func setting(shared: Bool) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: tags,
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func adding(tag: String) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: Set(tags + [tag]),
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func adding(tags: Set<String>) -> Bookmark {
        Bookmark(identifier: identifier,
                 title: title,
                 url: url,
                 tags: self.tags.union(tags),
                 date: date,
                 toRead: toRead,
                 shared: shared,
                 notes: notes)
    }

    public func url(_ location: Location) throws -> URL {
        switch location {
        case .web:
            return url
        case .internetArchive:
            return try "https://web.archive.org/web/*/".url.appendingPathComponent(url.absoluteString)
        case .pinboard:
            return try "https://pinboard.in/add".url.settingQueryItems([
                URLQueryItem(name: "url", value: url.absoluteString)
            ])
        }
    }

}

extension Bookmark: Identifiable {

    public var id: String { identifier }

}

extension Bookmark: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

}

extension Bookmark: CustomStringConvertible {

    public var description: String {
        "\(url.absoluteString) (title: \(title), tags: [\(tags.joined(separator: ", "))], date: \(date), toRead: \(toRead), notes: '\(self.notes)')"
    }

}

extension Bookmark {

    public var localDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .long
        return "Added \(dateFormatter.string(from: date))"
    }

}

extension Set where Element == Bookmark {

    public var containsUnreadBookmark: Bool {
        self.first { $0.toRead } != nil
    }

    public var containsPublicBookmark: Bool {
        self.first { $0.shared } != nil
    }

    public var tags: Set<String> {
        reduce(Set<String>()) { result, bookmark in
            result.union(bookmark.tags)
        }
    }

}

extension Pinboard.Post {

    // TODO: Review the nullability of the properties on the Pinboard.Post struct #216
    //       https://github.com/inseven/bookmarks/issues/216
    init(_ bookmark: Bookmark) {
        self.init(href: bookmark.url,
                  description: bookmark.title,
                  extended: bookmark.notes,
                  hash: "",
                  meta: "",
                  shared: bookmark.shared,
                  tags: Array(bookmark.tags),
                  time: bookmark.date,
                  toRead: bookmark.toRead)
    }

}
