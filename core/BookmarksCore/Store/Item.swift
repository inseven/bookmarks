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
import UIKit

public class Item: NSObject, NSSecureCoding {

    public let identifier: String
    public let title: String
    public let url: URL
    public let tags: [String]
    public let date: Date
    public let thumbnail: UIImage?

    init(identifier: String, title: String, url: URL, tags: [String], date: Date, thumbnail: UIImage? = nil) {
        self.identifier = identifier
        self.title = title
        self.url = url
        self.tags = tags
        self.date = date
        self.thumbnail = thumbnail
    }

    public static var supportsSecureCoding: Bool { true }

    static let identifierKey = "identifier"
    static let titleKey = "title"
    static let urlKey = "url"
    static let tagsKey = "tags"
    static let dateKey = "date"

    public func encode(with coder: NSCoder) {
        coder.encode(identifier, forKey: Item.identifierKey)
        coder.encode(title, forKey: Item.titleKey)
        coder.encode(url, forKey: Item.urlKey)
        coder.encode(tags, forKey: Item.tagsKey)
        coder.encode(date, forKey: Item.dateKey)
    }

    public convenience required init?(coder: NSCoder) {
        guard let identifier = coder.decodeString(forKey: Item.identifierKey),
              let title = coder.decodeString(forKey: Item.titleKey),
              let url = coder.decodeUrl(forKey: Item.urlKey),
              let tags = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: Item.tagsKey) as [String]?,
              let date = coder.decodeDate(forKey: Item.dateKey) else {
            return nil
        }
        self.init(identifier: identifier, title: title, url: url, tags: tags, date: date)
    }

}

extension Item: Identifiable {
    public var id: String { identifier }
}
