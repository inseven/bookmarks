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

class Document {

    let location: URL
    let contents: TFHpple

    init(location: URL, contents: TFHpple) {
        self.location = location
        self.contents = contents
    }

    var openGraphImage: SafeImage? {
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

    func image(for query: String) throws -> SafeImage {
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
        guard let image = SafeImage.init(contentsOf: url) else {
            throw OpenGraphError.invalidArgument(message: "Unable to fetch image")
        }
        return image
    }

}
