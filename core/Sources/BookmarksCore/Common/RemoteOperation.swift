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

// TODO: Should the title be a type? Or a localizable key?
// TODO: Perhaps the kind should be templated.

protocol RemoteOperation {

    var title: String { get }

    func perform(database: Database,
                 state: Updater.ServiceState,
                 progress: @escaping (Progress) -> Void) async throws -> Updater.ServiceState

}

struct RefreshOperation: RemoteOperation {

    let title = "Update"

    let force: Bool

    func perform(database: Database,
                 state: Updater.ServiceState,
                 progress: @escaping (Progress) -> Void) async throws -> Updater.ServiceState {
        progress(.active)
        let pinboard = Pinboard(token: state.token)
        let update = try pinboard.postsUpdate()
        if let lastUpdate = state.lastUpdate,
           lastUpdate >= update.updateTime,
           !force {
            print("skipping empty update")
            return state
        }

        // Get the posts.
        let posts = try pinboard.postsAll()

        var identifiers = Set<String>()

        // Insert or update bookmarks.
        for (index, post) in posts.enumerated() {
            progress(.value((Float(index + 1) / Float(posts.count))))
            guard let bookmark = Bookmark(post) else {
                continue
            }
            identifiers.insert(bookmark.identifier)
            _ = try database.insertOrUpdateBookmark(bookmark)
        }

        // Delete missing bookmarks.
        let allIdentifiers = try database.identifiers()
        let deletedIdentifiers = Set(allIdentifiers).subtracting(identifiers)
        for identifier in deletedIdentifiers {
            let bookmark = try database.bookmarkSync(identifier: identifier)
            print("deleting \(bookmark)...")
            _ = try database.deleteBookmark(identifier: identifier)
        }
        print("update complete")

        // Update the last update date.
        var newState = state
        newState.lastUpdate = update.updateTime
        return newState
    }

}

struct UpdateBookmark: RemoteOperation {

    let title = "Update bookmark"
    let bookmark: Bookmark

    func perform(database: Database,
                 state: Updater.ServiceState,
                 progress: @escaping (Progress) -> Void) async throws -> Updater.ServiceState {
        let pinboard = Pinboard(token: state.token)
        let post = Pinboard.Post(bookmark)
        try pinboard.postsAdd(post: post, replace: true)
        return state
    }

}

struct DeleteBookmark: RemoteOperation {

    let title = "Delete bookmark"
    let bookmark: Bookmark

    func perform(database: Database,
                 state: Updater.ServiceState,
                 progress: @escaping (Progress) -> Void) async throws -> Updater.ServiceState {
        let pinboard = Pinboard(token: state.token)
        try pinboard.postsDelete(url: bookmark.url)
        return state
    }

}
