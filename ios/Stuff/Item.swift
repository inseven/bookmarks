//
//  Item.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 31/10/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class Item {

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

}

extension Item: Identifiable {
    public var id: String { identifier }
}
