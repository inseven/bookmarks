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

extension Array where Element == String {

    var keywords: [String] {
        reduce(into: [String]()) { partialResult, string in
            partialResult.append(contentsOf: string.keywords)
        }
    }

}

public extension String {

    func replacingCharacters(in characterSet: CharacterSet, with replacement: String) -> String {
        components(separatedBy: characterSet)
            .filter { !$0.isEmpty }  // TODO: Make this clear that it replaces n+ characters
            .joined(separator: replacement)
    }

    var safeKeyword: String {
        lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingCharacters(in: CharacterSet.letters.inverted, with: " ")
            .trimmingCharacters(in: CharacterSet.whitespaces)
            .replacingCharacters(in: CharacterSet.whitespaces, with: "-")
    }

    var keywords: [String] {
        components(separatedBy: CharacterSet(charactersIn: ",/"))
            .map { $0.safeKeyword }
            .filter { !$0.isEmpty }
    }

}

public class Document {

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

    public func first(query: String) throws -> String {
        guard let elements = contents.search(withXPathQuery: query) as? [TFHppleElement] else {
            throw OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")
        }
        guard let element = elements.first else {
            throw OpenGraphError.invalidArgument(message: "Malformed open graph image tag")
        }
        guard let content = element.content else {
            throw OpenGraphError.invalidArgument(message: "Image tag had no content")
        }
        return content
    }

    public func contents(query: String) -> [String] {
        guard let elements = contents.search(withXPathQuery: query) as? [TFHppleElement] else {
            return []
        }
        return elements.compactMap { element in element.content }
    }

    public var keywords: [String] {
        get {
            // TODO: Case insensitive searches
            let queries = [
                "//meta[@name='Keywords']/@content",
                "//meta[@name='keywords']/@content",
                "//meta[@name='parsely-tags']/@content",
                "//meta[@name='sailthru.tags']/@content",
            ]
            let results = queries.map { contents(query: $0) }
            let flattendResults = results.reduce([String]()) { partialResult, result in
                return partialResult + result
            }
            return flattendResults.keywords
        }
    }

    public var tags: [String] {
        contents(query: "//meta[@property='article:tag']/@content")
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
