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

struct SidebarLink: View {

    var selection: Binding<BookmarksSection?>
    var tag: BookmarksSection
    var title: String
    var systemImage: String
    var databaseView: ItemsView

    func selectionActiveBinding(_ tag: BookmarksSection) -> Binding<Bool> {
        return Binding {
            selection.wrappedValue == tag
        } set: { value in
            guard value == true else {
                return
            }
            selection.wrappedValue = tag
        }
    }

    var body: some View {
        NavigationLink(destination: ContentView(sidebarSelection: selection, databaseView: databaseView)
                        .navigationTitle(title),
                       isActive: selectionActiveBinding(tag)) {
            Label(title, systemImage: systemImage)
        }
        .tag(tag)  // We set a tag so the list view knows what's selected...
        .id(tag)   // ... and an id so we can scroll to the items 🤦🏻‍♂️
    }

}
