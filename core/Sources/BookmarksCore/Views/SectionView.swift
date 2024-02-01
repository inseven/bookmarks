// Copyright (c) 2020-2024 InSeven Limited
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

import QuickLook
import SwiftUI

import Interact

public struct SectionView: View {

    let applicationModel: ApplicationModel

    @StateObject var sectionViewModel: SectionViewModel

    init(applicationModel: ApplicationModel,
                sceneState: Binding<SceneState>,
                section: BookmarksSection,
                openWindow: OpenWindowAction) {
        self.applicationModel = applicationModel
        _sectionViewModel = StateObject(wrappedValue: SectionViewModel(applicationModel: applicationModel,
                                                                       sceneState: sceneState,
                                                                       section: section,
                                                                       openWindow: openWindow))
    }

    public var body: some View {
        VStack {
            switch sectionViewModel.layoutMode {
            case .grid:
                SectionGridView()
            case .table:
                SectionTableView()
            }
        }
        .overlay(sectionViewModel.bookmarks.isEmpty ? PlaceholderView("No Bookmarks") : nil)
        .overlay(sectionViewModel.state == .loading ? LoadingView() : nil)
        .navigationTitle(sectionViewModel.title)
#if os(macOS)
        .navigationSubtitle(sectionViewModel.subtitle)
        .quickLookPreview($sectionViewModel.previewURL, in: sectionViewModel.urls)
#endif
        .searchable(text: $sectionViewModel.filter,
                    tokens: $sectionViewModel.tokens,
                    suggestedTokens: $sectionViewModel.suggestedTokens) { token in
            Label(token, systemImage: "tag")
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sectionViewModel.showTags()
                } label: {
                    Image(systemName: "tag")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    LayoutPicker()
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await applicationModel.refresh()
        }
#endif
        .presents($sectionViewModel.lastError)
        .environmentObject(sectionViewModel)
        .focusedSceneObject(sectionViewModel)
        .runs(sectionViewModel)
    }
}
