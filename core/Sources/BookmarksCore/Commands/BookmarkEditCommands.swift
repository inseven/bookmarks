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

import SwiftUI

struct BookmarkEditCommands: View {

    @Environment(\.openWindow) var openWindow

    @ObservedObject var sectionViewModel: SectionViewModel

    var body: some View {

        let bookmarks = sectionViewModel.bookmarks()
        let containsUnreadBookmark = bookmarks.containsUnreadBookmark
        let containsPublicBookmark = bookmarks.containsPublicBookmark

        Button(containsUnreadBookmark ? "Mark as Read" : "Mark as Unread") {
            sectionViewModel.update(toRead: !containsUnreadBookmark)
        }
        .keyboardShortcut("u", modifiers: [.command, .shift])
        .disabled(sectionViewModel.selection.isEmpty)

        Button(containsPublicBookmark ? "Make Private" : "Make Public") {
            await sectionViewModel.update(shared: !containsPublicBookmark)
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(sectionViewModel.selection.isEmpty)

        Divider()

        Button("Edit") {
            for id in sectionViewModel.selection {
                openWindow(value: id)
            }
        }
        .disabled(sectionViewModel.selection.isEmpty)
        .keyboardShortcut("e", modifiers: [.command])

    }

}
