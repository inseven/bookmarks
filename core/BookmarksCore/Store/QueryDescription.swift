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

import SQLite

public protocol QueryDescription {

    var sql: String { get }

}

public struct Untagged: QueryDescription {

    public var sql: String { "items.id NOT IN (SELECT item_id FROM items_to_tags)" }

    public init() { }

}

public struct Unread: QueryDescription {

    public var sql: String { "items.to_read = 1" }

    public init() { }
    
}

public struct Shared: QueryDescription {

    var shared: Bool

    public var sql: String { "items.shared = \(shared ? "1" : "0")" }

    public init(_ shared: Bool) {
        self.shared = shared
    }

}


public struct Tag: QueryDescription {

    let name: String

    public var sql: String {
        let tagsFilter = Database.Schema.name.lowercaseString == name.lowercased()
        let tagSubselect = """
            SELECT
                item_id
            FROM
                items_to_tags
            JOIN
                tags
            ON
                items_to_tags.tag_id = tags.id
            WHERE
                \(tagsFilter.asSQL())
            """
        return "items.id IN (\(tagSubselect))"
    }

    public init(_ name: String) {
        self.name = name
    }

}

public struct Like: QueryDescription {

    let filter: String

    public var sql: String {
        let tagsColumn = Expression<String>("tags")
        let expression =
            Database.Schema.title.like("%\(filter)%") ||
            Database.Schema.url.like("%\(filter)%") ||
            tagsColumn.like("%\(filter)%") ||
            Database.Schema.notes.like("%\(filter)%")
        return expression.asSQL()
    }

    init(_ filter: String) {
        self.filter = filter
    }

}

public struct Search: QueryDescription {

    let search: String

    public var sql: String {
        search.tokens.map { Like($0) }.reduce(True() as QueryDescription) { And($0, $1) }.sql
    }

    init(_ search: String) {
        self.search = search
    }

}

public struct And: QueryDescription {

    let lhs: QueryDescription
    let rhs: QueryDescription

    public var sql: String { "(\(lhs.sql)) AND (\(rhs.sql))" }

    init(_ lhs: QueryDescription, _ rhs: QueryDescription) {
        self.lhs = lhs
        self.rhs = rhs
    }

}

// TODO: Flatten AND queries into single arrays where possible #201
//       https://github.com/inseven/bookmarks/issues/201
func &&<T: QueryDescription, Q: QueryDescription>(lhs: T, rhs: Q) -> And {
    return And(lhs, rhs)
}

public struct True: QueryDescription {

    public var sql: String { "1" }

    public init() { }

}

public class Filter: QueryDescription {

    var search: String

    public var sql: String {
        var query: QueryDescription = True()
        let tagPrefix = "tag:"
        for token in search.tokens {
            if token.hasPrefix(tagPrefix) {
                let tag = String(token.dropFirst(tagPrefix.count))
                query = And(query, Tag(tag))
            } else {
                query = And(query, Like(token))
            }
        }
        return query.sql
    }

    init(_ search: String) {
        self.search = search
    }

}

public class Today: QueryDescription {

    public var sql: String {
        "date >= datetime('now', '-1 day')"
    }

    public init() { }

}
