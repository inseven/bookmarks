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

import Carbon
import Combine
import QuickLook
import SwiftUI

import BookmarksCore
import Interact
import SelectableCollectionView

struct SectionView: View {

    let manager: BookmarksManager

    @StateObject var sectionViewModel: SectionViewModel

    let layout = ColumnLayout(spacing: 2.0,
                              columns: 5,
                              edgeInsets: NSEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))

    init(manager: BookmarksManager, section: BookmarksSection) {
        self.manager = manager
        _sectionViewModel = StateObject(wrappedValue: SectionViewModel(manager: manager, section: section))
    }

    @MenuItemBuilder private func contextMenu(_ selection: Set<Bookmark.ID>) -> [MenuItem] {
        MenuItem("Open") {
            sectionViewModel.open(ids: selection)
        }
        MenuItem("Open on Internet Archive") {
            sectionViewModel.open(ids: selection, location: .internetArchive)
        }
        Separator()
        MenuItem("Delete") {
            sectionViewModel.delete(ids: selection)
        }
        Separator()
        MenuItem(sectionViewModel.selectionContainsUnreadBookmarks ? "Mark as Read" : "Mark as Unread") {
            sectionViewModel.update(toRead: !sectionViewModel.selectionContainsUnreadBookmarks)
        }
        MenuItem(sectionViewModel.selectionContainsPublicBookmark ? "Make Private" : "Make Public") {
            sectionViewModel.update(shared: !sectionViewModel.selectionContainsPublicBookmark)
        }
        Separator()
        MenuItem("Edit on Pinboard") {
            sectionViewModel.open(ids: selection, location: .pinboard)
        }
        Separator()
        MenuItem("Copy") {
            sectionViewModel.copy(ids: selection)
        }
        MenuItem("Copy Tags") {
            sectionViewModel.copyTags(ids: selection)
        }
    }

    @MainActor func primaryAction(_ selection: Set<Bookmark.ID>) {
        sectionViewModel.open(ids: selection)
    }

    var body: some View {
        VStack {

            switch sectionViewModel.layoutMode {
            case .grid:

                SelectableCollectionView(sectionViewModel.bookmarks,
                                         selection: $sectionViewModel.selection,
                                         layout: layout) { bookmark in

                    BookmarkCell(manager: manager, bookmark: bookmark)
                        .modifier(BorderedSelection())
                        .padding(4.0)
                        .shadow(color: .shadow, radius: 4.0)

                } contextMenu: { selection in
                    contextMenu(selection)
                } primaryAction: { selection in
                    primaryAction(selection)
                } keyDown: { event in
                    if event.keyCode == kVK_Space {
                        sectionViewModel.showPreview()
                        return true
                    }
                    return false
                } keyUp: { event in
                    if event.keyCode == kVK_Space {
                        return true
                    }
                    return false
                }

            case .table:

                Table(sectionViewModel.bookmarks, selection: $sectionViewModel.selection) {
                    TableColumn("Title", value: \.title)
                    TableColumn("URL", value: \.url.absoluteString)
                    TableColumn("Tags") { bookmark in
                        Text(bookmark.tags.joined(separator: " "))
                    }
                }
                .contextMenu(forSelectionType: Bookmark.ID.self) { selection in
                    contextMenu(selection)
                } primaryAction: { selection in
                    primaryAction(selection)
                }
            }

        }
        .overlay(sectionViewModel.state == .loading ? LoadingView() : nil)
        .quickLookPreview($sectionViewModel.previewURL, in: sectionViewModel.urls)
        .runs(sectionViewModel)
        .searchable(text: $sectionViewModel.filter,
                    tokens: $sectionViewModel.tokens,
                    suggestedTokens: $sectionViewModel.suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
        .navigationTitle(sectionViewModel.title)
        .navigationSubtitle(sectionViewModel.subtitle)
        .sheet(item: $sectionViewModel.sheet) { sheet in
            switch sheet {
            case .addTags:
                AddTagsView(tagsModel: manager.tagsModel, sectionViewModel: sectionViewModel)
            }
        }
        .presents($sectionViewModel.lastError)
        .focusedSceneObject(sectionViewModel)
    }
}
