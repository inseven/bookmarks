//
//  Document.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class Document {

    let location: URL
    let contents: TFHpple

    init(location: URL, contents: TFHpple) {
        self.location = location
        self.contents = contents
    }

    var openGraphImage: UIImage? {
        get {
            if let image = try? self.image(for: "//meta[@property='og:image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@name='og:image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@name='image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@itemprop='image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@name='twitter:image']/@content") {
                return image
            }
            return nil
        }
    }

    func image(for query: String) throws -> UIImage {
        guard let elements = contents.search(withXPathQuery: query) as? [TFHppleElement] else {
            throw OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")
        }
        guard let element = elements.first else {
            throw OpenGraphError.invalidArgument(message: "Malformed open graph image tag")
        }
        guard let content = element.content else {
            throw OpenGraphError.invalidArgument(message: "Image tag had no content")
        }
        guard let components = URLComponents(unsafeString: content) else {
            throw OpenGraphError.invalidArgument(message: "Unable to create URL components")
        }
        guard let url = components.url(relativeTo: self.location) else {
            throw OpenGraphError.invalidArgument(message: "Inavlid image URL")
        }
        guard let image = UIImage.init(contentsOf: url) else {
            throw OpenGraphError.invalidArgument(message: "Unable to fetch image")
        }
        return image
    }

}
