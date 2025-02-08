// Copyright (c) 2020-2025 Jason Morley
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

public protocol Sectionable {

    var section: BookmarksSection { get }

}

public enum BookmarksSection: Equatable, Codable {

    case all
    case untagged
    case today
    case unread
    case shared(_ shared: Bool)
    case tag(String)

}

extension BookmarksSection: CustomStringConvertible, Hashable, Identifiable {

    public var id: String { self.rawValue }

    public var description: String { self.rawValue }

}

extension String: Sectionable {

    public var section: BookmarksSection {
        return .tag(self)
    }

}

extension BookmarksSection: RawRepresentable {

    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "uk.co.jbmorley.bookmarks.sections.all-bookmarks":
            self = .all
        case "uk.co.jbmorley.bookmarks.sections.untagged":
            self = .untagged
        case "uk.co.jbmorley.bookmarks.sections.unread":
            self = .unread
        case "uk.co.jbmorley.bookmarks.sections.today":
            self = .today
        case "uk.co.jbmorley.bookmarks.sections.shared":
            self = .shared(true)
        case "uk.co.jbmorley.bookmarks.sections.shared.false":
            self = .shared(false)
        case _ where rawValue.starts(with: "uk.co.jbmorley.bookmarks.sections.tags."):
            self = .tag(String(rawValue.dropFirst("uk.co.jbmorley.bookmarks.sections.tags.".count)))
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .all:
            return "uk.co.jbmorley.bookmarks.sections.all-bookmarks"
        case .untagged:
            return "uk.co.jbmorley.bookmarks.sections.untagged"
        case .unread:
            return "uk.co.jbmorley.bookmarks.sections.unread"
        case .today:
            return "uk.co.jbmorley.bookmarks.sections.today"
        case .shared(true):
            return "uk.co.jbmorley.bookmarks.sections.shared"
        case .shared(false):
            return "uk.co.jbmorley.bookmarks.sections.shared.false"
        case .tag(let tag):
            return "uk.co.jbmorley.bookmarks.sections.tags.\(tag)"
        }
    }

}

extension Optional: RawRepresentable where Wrapped == BookmarksSection {

    public typealias RawValue = String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else {
            return nil
        }
        self = BookmarksSection(rawValue: rawValue)
    }

    public var rawValue: String {
        guard let bookmarksSection = self else {
            return ""
        }
        return bookmarksSection.rawValue
    }

}

public extension BookmarksSection {

    var query: AnyQuery {
        switch self {
        case .all:
            return True().eraseToAnyQuery()
        case .untagged:
            return Untagged().eraseToAnyQuery()
        case .today:
            return Today().eraseToAnyQuery()
        case .unread:
            return Unread().eraseToAnyQuery()
        case .shared(let shared):
            return Shared(shared).eraseToAnyQuery()
        case .tag(tag: let tag):
            return Tag(tag).eraseToAnyQuery()
        }
    }

    var navigationTitle: String {
        switch self {
        case .all:
            return "All Bookmarks"
        case .untagged:
            return "Untagged"
        case .today:
            return "Today"
        case .unread:
            return "Read Later"
        case .shared(let shared):
            if shared {
                return "Public"
            } else {
                return "Private"
            }
        case .tag(tag: let tag):
            return "Bookmarks tagged \"\(tag)\""
        }
    }

    var sidebarTitle: String {
        switch self {
        case .all:
            return "All Bookmarks"
        case .untagged:
            return "Untagged"
        case .today:
            return "Today"
        case .unread:
            return "Read Later"
        case .shared(let shared):
            if shared {
                return "Public"
            } else {
                return "Private"
            }
        case .tag(tag: let tag):
            return tag
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "bookmark"
        case .untagged:
            return "tag"
        case .today:
            return "sun.max"
        case .unread:
            return "book"
        case .shared(let shared):
            if shared {
                return "globe"
            } else {
                return "lock"
            }
        case .tag:
            return "tag"
        }
    }

}
