// Copyright (c) 2020-2021 Jason Barrie Morley
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

import Combine
import SwiftUI

enum BookmarksError: Error {
    case resizeFailure
}

extension String: Identifiable {
    public var id: String { self }
}

struct SearchBoxModifier: ViewModifier {

    @Binding var text: String
    @State var hover = false

    func body(content: Content) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            content
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8.0)
        .background(hover ? Color.pink : Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .onHover { hover in
            self.hover = hover
        }
    }

}

struct ContentView: View {

    @Environment(\.manager) var manager: BookmarksManager
    @ObservedObject var store: Store
    @State var selected = true
    @State var filter = ""

    var body: some View {
        NavigationView {
            BookmarksView(store: store, title: "All Bookmarks")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

extension BookmarksView.SheetType: Identifiable {
    public var id: Self { self }
}
