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

import SwiftUI

import BookmarksCore

struct BookmarkEditCommands: View {

    @Environment(\.manager) var manager: BookmarksManager

    var item: Item

    var body: some View {
        Button(item.toRead ? "Mark as Read" : "Mark as Unread") {
            // TODO: Show errors in the UI #218
            //       https://github.com/inseven/bookmarks/issues/218
            manager.updateItem(item: item.setting(toRead: !item.toRead), completion: Logging.log("read/unread"))
        }
        Button(item.shared ? "Make Private" : "Make Public") {
            // TODO: Show errors in the UI #218
            //       https://github.com/inseven/bookmarks/issues/218
            manager.updateItem(item: item.setting(shared: !item.shared), completion: Logging.log("private/public"))
        }
        Button("Edit on Pinboard") {
            do {
                NSWorkspace.shared.open(try item.pinboardUrl())
            } catch {
                print("Failed to edit with error \(error)")
            }
        }
    }
}
