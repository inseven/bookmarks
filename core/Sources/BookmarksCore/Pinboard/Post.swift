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

import Foundation

extension Pinboard {

    // TODO: Review the nullability of the properties on the Pinboard.Post struct #216
    //       https://github.com/inseven/bookmarks/issues/216
    public struct Post: Codable {

        public var description: String
        public var extended: String
        public var hash: String
        public var href: URL?
        public var meta: String
        public var shared: Bool
        public var tags: [String]
        public var time: Date?
        public var toRead: Bool

        public enum CodingKeys: String, CodingKey {
            case description = "description"
            case extended = "extended"
            case hash = "hash"
            case href = "href"
            case meta = "meta"
            case shared = "shared"
            case tags = "tags"
            case time = "time"
            case toRead = "toread"
        }

        public init(href: URL,
             description: String = "",
             extended: String = "",
             hash: String = "",
             meta: String = "",
             shared: Bool = true,
             tags: [String] = [],
             time: Date? = Date(),
             toRead: Bool = false) {
            self.href = href
            self.description = description
            self.extended = extended
            self.hash = hash
            self.meta = meta
            self.shared = shared
            self.tags = tags
            self.time = time
            self.toRead = toRead
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Unfortunately, the Pinboard API uses 0 as a placeholder for a missing description, so we need to do a
            // little dance here to keep everything happy.
            do {
                description = try container.decode(String.self, forKey: .description)
            } catch DecodingError.typeMismatch {
                // We double check that we can parse the key as a boolean to ensure the structure is as we expect.
                let _ = try container.decode(Bool.self, forKey: .description)
                description = ""
            }

            extended = try container.decode(String.self, forKey: .extended)
            href = URL(string: try container.decode(String.self, forKey: .href))
            hash = try container.decode(String.self, forKey: .hash)
            meta = try container.decode(String.self, forKey: .meta)
            shared = try container.decode(Boolean.self, forKey: .shared) == .yes ? true : false
            tags = try container.decode(String.self, forKey: .tags).split(separator: " ").map(String.init)
            time = ISO8601DateFormatter.init().date(from: try container.decode(String.self, forKey: .time))
            toRead = try container.decode(Boolean.self, forKey: .toRead) == .yes ? true : false
        }
    }

}

extension Bookmark {

    init?(_ post: Pinboard.Post) {
        guard
            let url = post.href,
            let date = post.time else {
                return nil
        }
        self.init(identifier: post.hash,
                  title: post.description,
                  url: url,
                  tags: Set(post.tags),
                  date: date,
                  toRead: post.toRead,
                  shared: post.shared,
                  notes: post.extended)
    }

}
