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

struct Bookmarks: View {

    enum SheetType {
        case settings
        case tags(Bookmark)
    }

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var bookmarksView: BookmarksView

    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))
    @State var sheet: SheetType?

    @State var search: String = ""
    @State var sharedItems: [Any]?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(bookmarksView.bookmarks) { bookmark in
                    BookmarkCell(bookmark: bookmark)
                        .onTapGesture {
                            UIApplication.shared.open(bookmark.url)
                        }
                        .contextMenu(ContextMenu {
                            Button {
                                sharedItems = [bookmark.url]
                            } label: {
                                HStack {
                                    Text("Share")
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            Divider()
                            Button {
                                sheet = .tags(bookmark)
                            } label: {
                                HStack {
                                    Text("Tags")
                                    Spacer()
                                    Image(systemName: "tag")
                                }
                            }
                        })
                }
            }
            .padding()
        }
        .searchable(text: $searchDebouncer.value)
        .sharing(items: $sharedItems)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView(settings: manager.settings)
                }
            case .tags(let bookmark):
                AddTagsView(tagsView: manager.tagsView, bookmark: bookmark)
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarItems(leading: Button("Settings") {
            sheet = .settings
        })
        .onAppear {
            bookmarksView.start()
        }
        .onDisappear {
            bookmarksView.stop()
        }
        .onReceive(searchDebouncer.$debouncedValue) { value in
            bookmarksView.query = AnyQuery.parse(filter: value)
        }
    }

}

extension Bookmarks.SheetType: Identifiable {
    
    public var id: String {
        switch self {
        case .settings:
            return "settings"
        case .tags(let bookmark):
            return "tags-\(bookmark.id)"
        }
    }
    
}
