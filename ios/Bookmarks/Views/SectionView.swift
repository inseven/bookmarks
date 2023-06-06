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

    let applicationModel: ApplicationModel

    @StateObject var sectionViewModel: SectionViewModel

    init(applicationModel: ApplicationModel, sceneModel: SceneModel, section: BookmarksSection) {
        self.applicationModel = applicationModel
        _sectionViewModel = StateObject(wrappedValue: SectionViewModel(applicationModel: applicationModel,
                                                                       sceneModel: sceneModel,
                                                                       section: section))
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
                                    sectionViewModel.open(ids: [bookmark.id])
                                }
                                .contextMenu {
                                    sectionViewModel.contextMenu([bookmark.id])
                                }
                        }
                    }
                    .padding()
                }
            case .table:
                SectionTableView()
            }

        }
        .overlay(sectionViewModel.state == .loading ? LoadingView() : nil)
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

            ToolbarItem {
                Button {
                    applicationModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

        }
        .searchable(text: $sectionViewModel.filter,
                    tokens: $sectionViewModel.tokens,
                    suggestedTokens: $sectionViewModel.suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
        .environmentObject(sectionViewModel)
        .focusedSceneObject(sectionViewModel)
        .runs(sectionViewModel)
    }

}
