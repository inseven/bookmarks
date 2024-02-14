// Copyright (c) 2020-2024 Jason Morley
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

import SwiftSoup

enum URLFormat {
    case short
}

extension URL: Identifiable {

    static let actionScheme = "bookmarks-action"

    public var id: Self { self }

    var components: URLComponents {
        get throws {
            guard let components = URLComponents(string: absoluteString) else {
                throw BookmarksError.invalidURL(self)
            }
            return components
        }
    }

    var faviconURL: URL? {
        return URL(string: "/favicon.ico", relativeTo: self)
    }

    init?(forOpeningTag tag: String) {
        var components = URLComponents()
        components.scheme = Self.actionScheme
        components.path = "/show"
        components.queryItems = [
            URLQueryItem(name: "tag", value: tag)
        ]
        guard let actionURL = components.url else {
            return nil
        }
        self = actionURL
    }

    func settingQueryItems(_ queryItems: [URLQueryItem]) throws -> URL {
        var components = try components
        components.queryItems = queryItems
        return try components.safeUrl
    }

    func formatted(_ format: URLFormat) -> String {
        switch format {
        case .short:
            return host ?? absoluteString
        }
    }

    public func document() async throws -> SwiftSoup.Document {
        let (data, _) = try await URLSession.shared.data(from: self)
        guard let html = String(data: data, encoding: .utf8) else {
            throw BookmarksError.invalidResponse
        }
        return try SwiftSoup.parse(html, self.absoluteString)
    }

    public func title() async throws -> String? {
        return try await document().title()
    }

}
