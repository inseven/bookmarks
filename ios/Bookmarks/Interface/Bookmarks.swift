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

struct Bookmarks: View {

    enum SheetType: Identifiable {

        public var id: String {
            switch self {
            case .tags(let bookmark):
                return "tags-\(bookmark.id)"
            }
        }

        case tags(Bookmark)
    }

    @Environment(\.manager) var manager: BookmarksManager
    
    var section: BookmarksSection

    @StateObject var bookmarksView: BookmarksView
    @State var sheet: SheetType?
    @State var error: Error?
    
    func perform(action: @escaping () async throws -> Void) {
        Task(priority: .high) {
            do {
                try await action()
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(bookmarksView.bookmarks) { bookmark in
                    BookmarkCell(bookmark: bookmark)
                        .onTapGesture {
                            UIApplication.shared.open(bookmark.url)
                        }
                        .contextMenu(ContextMenu {
                            ShareLink("Share", item: bookmark.url)
                            Button {
                                sheet = .tags(bookmark)
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }
                            if bookmark.toRead {
                                Button {
                                    perform {
                                        try await manager.updateBookmarks([bookmark.setting(toRead: false)])
                                    }
                                } label: {
                                    Label("Mark as Read", systemImage: "circle")
                                }
                            } else {
                                Button {
                                    perform {
                                        try await manager.updateBookmarks([bookmark.setting(toRead: true)])
                                    }
                                } label: {
                                    Label("Mark as Unread", systemImage: "circle.inset.filled")
                                }
                            }
                            if bookmark.shared {
                                Button {
                                    perform {
                                        try await manager.updateBookmarks([bookmark.setting(shared: false)])
                                    }
                                } label: {
                                    Label("Make Private", systemImage: "lock")
                                }
                            } else {
                                Button {
                                    perform {
                                        try await manager.updateBookmarks([bookmark.setting(shared: true)])
                                    }
                                } label: {
                                    Label("Make Public", systemImage: "globe")
                                }
                            }
                            Button(role: .destructive) {
                                perform {
                                    try await manager.deleteBookmarks([bookmark])
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        })
                }
            }
            .padding()
        }
        .searchable(text: $bookmarksView.filter,
                    tokens: $bookmarksView.tokens,
                    suggestedTokens: $bookmarksView.suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .tags(let bookmark):
                EditView(tagsView: manager.tagsView, bookmark: bookmark)
            }
        }
        .alert(isPresented: $error.mappedToBool()) {
            Alert(error: error)
        }
        .navigationTitle(section.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bookmarksView.start()
        }
        .onDisappear {
            bookmarksView.stop()
        }
    }

}
