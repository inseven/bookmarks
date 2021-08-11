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

public enum BookmarksError: Error, Equatable {

    case resizeFailure

    case invalidURLString(String)
    case invalidURL(URL)
    case invalidURLComponents(URLComponents)

    case unknownMigration(version: Int32)

    case itemNotFoundIdentifier(String)
    case itemNotFoundURL(URL)
    case tagNotFound(String)

    case corrupt
    case timeout
    case malformedBookmark

    case openFailure
    
}

extension BookmarksError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .resizeFailure:
            return "Unable to resize image."
        case .invalidURLString(let string):
            return "\(string) is not a valid URL."
        case .invalidURL(let url):
            return "\(url) is not a valid URL."
        case .invalidURLComponents:
            return "Invalid URL"
        case .unknownMigration(let version):
            return "Failed to migrate database with unknown migration \(version)."
        case .itemNotFoundIdentifier(let identifier):
            return "Unable to find bookmark with identifier \(identifier)."
        case .itemNotFoundURL(let url):
            return "Unable to find bookmark with URL \(url.absoluteString)."
        case .tagNotFound(let tag):
            return "Unable to find tag \(tag)"
        case .corrupt:
            return "Database corrupt."
        case .timeout:
            return "Database timeout."
        case .malformedBookmark:
            return "Malformed bookmark."
        case .openFailure:
            return "Unable to open URL"
        }
    }

}
