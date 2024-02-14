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

public enum BookmarksError: Error, Equatable {

    case resizeFailure

    case invalidURLString(String)
    case invalidURL(URL)
    case invalidURLComponents(URLComponents)

    case unknownMigration(version: Int32)

    case bookmarkNotFoundByIdentifier(String)
    case bookmarkNotFoundByURL(URL)
    case tagNotFound(name: String)
    
    case inconsistentState

    case unauthorized
    case corrupt
    case timeout
    case malformedBookmark
    case unknownResponse
    case invalidResponse
    case httpError(HTTPStatus)
    
}

extension BookmarksError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .resizeFailure:
            return "Failed to resize image."
        case .invalidURLString:
            return "Invalid URL string."
        case .invalidURL:
            return "Invalid URL."
        case .invalidURLComponents:
            return "Invalid URL components."
        case .unknownMigration(let version):
            return "Unknown database migration version \(version)."
        case .bookmarkNotFoundByIdentifier:
            return "Bookmark not found by identifier."
        case .bookmarkNotFoundByURL:
            return "Bookmark not found by URL."
        case .tagNotFound:
            return "Tag not found."
        case .inconsistentState:
            return "Inconsistent state."
        case .unauthorized:
            return "Unauthorized."
        case .corrupt:
            return "Corrupt."
        case .timeout:
            return "Timeout."
        case .malformedBookmark:
            return "Malformed bookmark."
        case .unknownResponse:
            return "Unknown response."
        case .invalidResponse:
            return "Invalid response."
        case .httpError(let status):
            return "HTTP error \(status)."
        }
    }

}

