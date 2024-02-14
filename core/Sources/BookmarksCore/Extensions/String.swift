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

import SwiftUI

import HashRainbow

extension String: Identifiable {

    public var id: String { self }

    public func like(_ search: String) -> Bool {
        guard !search.isEmpty else {
            return true
        }
        return self.lowercased().contains(search.lowercased())
    }

    public var url: URL {
        get throws {
            guard let url = URL(string: self) else {
                throw BookmarksError.invalidURLString(self)
            }
            return url
        }
    }

    public var tokens: [String] {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    public func color() -> Color {
        return HashRainbow.colorForString(self, colors: .tags)
    }

    public func containsWhitespaceAndNewlines() -> Bool {
        return rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }

    public func pinboardTagUrl(for user: String) throws -> URL {
        return try "https://pinboard.in/u:\(user)/t:\(self)/".url
    }

    public func replacingCharacters(in characterSet: CharacterSet, with replacement: String) -> String {
         components(separatedBy: characterSet)
             .filter { !$0.isEmpty }
             .joined(separator: replacement)
     }

    public var safeKeyword: String {
         lowercased()
             .replacingOccurrences(of: ".", with: "")
             .replacingCharacters(in: CharacterSet.letters.inverted, with: " ")
             .trimmingCharacters(in: CharacterSet.whitespaces)
             .replacingCharacters(in: CharacterSet.whitespaces, with: "-")
     }

}
