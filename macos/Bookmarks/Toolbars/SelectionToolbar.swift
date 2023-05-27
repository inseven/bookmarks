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

import BookmarksCore

struct SelectionToolbar: CustomizableToolbarContent {

    @Environment(\.manager) var manager: BookmarksManager
    
    @ObservedObject var bookmarksView: BookmarksView

    var body: some CustomizableToolbarContent {

        ToolbarItem(id: "preview") {
            Button {
                bookmarksView.showPreview()
            } label: {
                Label("Preview", systemImage: "eye")
            }
            .help("Preview with Quick Look")
            .keyboardShortcut(.space, modifiers: [])
            .disabled(bookmarksView.selection.count != 1)
        }

        ToolbarItem(id: "open") {
            Button {
                bookmarksView.open(ids: bookmarksView.selection)
            } label: {
                Label("Open", systemImage: "safari")
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(bookmarksView.selection.isEmpty)
        }

        ToolbarItem(id: "tag") {
            Button {
                bookmarksView.addTags()
            } label: {
                Label("Add Tags", systemImage: "tag")
            }
            .help("Add Tags")
            .disabled(bookmarksView.selection.isEmpty)
        }

        ToolbarItem(id: "delete") {
            Button {
                bookmarksView.delete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help("Delete")
            .disabled(bookmarksView.selection.isEmpty)
        }

    }

}
