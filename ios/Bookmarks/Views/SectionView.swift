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

import Interact

import BookmarksCore

struct SectionView: View {

    enum SheetType: Identifiable {

        public var id: String {
            switch self {
            case .edit(let bookmark):
                return "edit-\(bookmark.id)"
            }
        }

        case edit(Bookmark)
    }

    let applicationModel: ApplicationModel

    @StateObject var sectionViewModel: SectionViewModel

    @State var sheet: SheetType? = nil
    @State var error: Error? = nil

    init(applicationModel: ApplicationModel, section: BookmarksSection) {
        self.applicationModel = applicationModel
        _sectionViewModel = StateObject(wrappedValue: SectionViewModel(applicationModel: applicationModel, section: section))
    }
    
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

    @ViewBuilder func contextMenu(for selection: Set<Bookmark.ID>) -> some View {

        let bookmarks = sectionViewModel.bookmarks(for: selection)
        let containsUnreadBookmark = bookmarks.containsUnreadBookmark
        let containsPublicBookmark = bookmarks.containsPublicBookmark

        ShareLink("Share", items: bookmarks.map({ $0.url }))

        if bookmarks.count == 1,
           let bookmark = bookmarks.first {

            Button {
                sheet = .edit(bookmark)
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }

        }

        Button {
            sectionViewModel.update(ids: selection, toRead: !containsUnreadBookmark)
        } label: {
            if containsUnreadBookmark {
                Label("Mark as Read", systemImage: "circle")
            } else {
                Label("Mark as Unread", systemImage: "circle.inset.filled")
            }
        }

        Button {
            sectionViewModel.update(ids: selection, shared: !containsPublicBookmark)
        } label: {
            if containsPublicBookmark {
                Label("Make Private", systemImage: "lock")
            } else {
                Label("Make Public", systemImage: "globe")
            }
        }

        Button(role: .destructive) {
            sectionViewModel.delete(ids: selection)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @MainActor func primaryAction(_ selection: Set<Bookmark.ID>) {
        sectionViewModel.open(ids: selection)
    }
    
    var body: some View {
        VStack {
            switch sectionViewModel.layoutMode {
            case .grid:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(sectionViewModel.bookmarks) { bookmark in
                            BookmarkCell(applicationModel: applicationModel, bookmark: bookmark)
                                .aspectRatio(8/9, contentMode: .fit)
                                .onTapGesture {
                                    primaryAction([bookmark.id])
                                }
                                .contextMenu(ContextMenu {
                                    contextMenu(for: [bookmark.id])
                                })
                        }
                    }
                    .padding()
                }
            case .table:
                SectionTableView()
                    .contextMenu(forSelectionType: Bookmark.ID.self) { selection in
                        contextMenu(for: selection)
                    } primaryAction: { selection in
                        primaryAction(selection)
                    }
            }

        }
        .navigationTitle(sectionViewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    LayoutPicker()
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $sectionViewModel.filter,
                    tokens: $sectionViewModel.tokens,
                    suggestedTokens: $sectionViewModel.suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .edit(let bookmark):
                EditView(tagsModel: applicationModel.tagsModel, bookmark: bookmark)
            }
        }
        .alert(isPresented: $error.mappedToBool()) {
            Alert(error: error)
        }
        .environmentObject(sectionViewModel)
        .focusedSceneObject(sectionViewModel)
        .runs(sectionViewModel)
    }

}
