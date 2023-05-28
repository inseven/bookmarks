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

struct ViewCommands: Commands {

    @ObservedObject var bookmarksView: BookmarksView

    init(bookmarksView: BookmarksView? = nil) {
        self.bookmarksView = bookmarksView ?? BookmarksView()
    }

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Picker(selection: $bookmarksView.layoutMode) {
                ForEach(LayoutMode.allCases) { layoutMode in
                    Label(Localized(layoutMode), systemImage: layoutMode.systemImage)
                        .tag(layoutMode)
                }
            } label: {
            }
            .pickerStyle(.inline)
            .disabled(bookmarksView.isPlaceholder)
        }
    }

}
