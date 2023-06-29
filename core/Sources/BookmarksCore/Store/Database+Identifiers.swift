// Copyright (c) 2020-2023 InSeven Limited
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

extension Database {

    struct Identifiers: AsyncSequence {
        typealias Element = Bookmark.ID

        let database: Database
        let lessThanVersion: Int64

        struct AsyncIterator: AsyncIteratorProtocol {

            let database: Database
            let lessThanVersion: Int64

            mutating func next() async throws -> Bookmark.ID? {
                while true {
                    if let identifier = try await database.identifier(metadataVersionLessThan: lessThanVersion) {
                        return identifier
                    }
                    // TODO: Since we're not observing until we've processed the last element this can drop chanegs.
                    _ = await database.wait()
                }
            }
        }

        func makeAsyncIterator() -> AsyncIterator {
            return AsyncIterator(database: database, lessThanVersion: lessThanVersion)
        }
    }

    func identifiers(metadataVersionLessThan version: Int64) -> Identifiers {
        return Identifiers(database: self, lessThanVersion: version)
    }

}
