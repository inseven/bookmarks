//
//  Item.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 31/10/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class Item: NSObject, NSSecureCoding {

    let identifier: String
    let title: String
    let url: URL
    let tags: [String]
    let date: Date
    let thumbnail: UIImage?

    init(identifier: String, title: String, url: URL, tags: [String], date: Date, thumbnail: UIImage? = nil) {
        self.identifier = identifier
        self.title = title
        self.url = url
        self.tags = tags
        self.date = date
        self.thumbnail = thumbnail
    }

    static var supportsSecureCoding: Bool { true }

    static let identifierKey = "identifier"
    static let titleKey = "title"
    static let urlKey = "url"
    static let tagsKey = "tags"
    static let dateKey = "date"

    func encode(with coder: NSCoder) {
        coder.encode(identifier, forKey: Item.identifierKey)
        coder.encode(title, forKey: Item.titleKey)
        coder.encode(url, forKey: Item.urlKey)
        coder.encode(tags, forKey: Item.tagsKey)
        coder.encode(date, forKey: Item.dateKey)
    }

    convenience required init?(coder: NSCoder) {
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
