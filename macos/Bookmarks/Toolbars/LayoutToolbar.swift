// Copyright (c) 2020-2022 InSeven Limited
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

struct LayoutToolbar: CustomizableToolbarContent {

    @FocusedObject var bookmarksView: BookmarksView?

    var layoutMode: Binding<LayoutMode> {
        guard let bookmarksView else {
            return Binding.constant(LayoutMode.grid)
        }
        return Binding {
            return bookmarksView.layoutMode
        } set: { layoutMode in
            bookmarksView.layoutMode = layoutMode
        }
    }

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "layout-mode") {
            Picker(selection: layoutMode) {
                ForEach(LayoutMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .tag(mode)
                }
            } label: {
            }
            .pickerStyle(.inline)
            .disabled(bookmarksView == nil)
        }

    }

}
