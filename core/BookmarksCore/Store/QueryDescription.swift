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

public struct HasTag: QueryDescription {

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

public struct Contains: QueryDescription {

    let filter: String

    public var sql: String {
        let tagsColumn = Expression<String>("tags")
        let expression = Database.Schema.title.like("%\(filter)%") || Database.Schema.url.like("%\(filter)%") || tagsColumn.like("%\(filter)%")
        return expression.asSQL()
    }

    init(_ filter: String) {
        self.filter = filter
    }

}

public struct MatchesFilter: QueryDescription {

    let filter: String

    public var sql: String {
        let tagsColumn = Expression<String>("tags")
        let filters = filter.tokens.map {
            Database.Schema.title.like("%\($0)%") || Database.Schema.url.like("%\($0)%") || tagsColumn.like("%\($0)%")
        }
        return filters.reduce(Expression(value: true)) { $0 && $1 }.asSQL()
    }

    init(_ filter: String) {
        self.filter = filter
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

// TODO: Why doesn't this work?
//extension QueryDescription {
//
//    static func &&(lhs: QueryDescription, rhs: QueryDescription) -> QueryDescription {
//        return And(lhs, rhs)
//    }
//
//}

public struct True: QueryDescription {

    public var sql: String { "1" }

    public init() { }

}

public class Search: QueryDescription {

    var search: String

    public var sql: String {
        var query: QueryDescription = True()
        let tagPrefix = "tag:"
        for token in search.tokens {
            if token.hasPrefix(tagPrefix) {
                let tag = String(token.dropFirst(tagPrefix.count))
                query = And(query, HasTag(tag))
            } else {
                query = And(query, Contains(token))
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
