// Copyright (c) 2020-2025 Jason Morley
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

#if os(macOS)

import Carbon
import SwiftUI

import SelectableCollectionView

public struct MacSectionGridView: View {

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var sectionViewModel: SectionViewModel

    let layout = ColumnLayout(spacing: 6.0,
                              columns: 5,
                              edgeInsets: NSEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))

    public init() {

    }

    public var body: some View {
        SelectableCollectionView(sectionViewModel.bookmarks,
                                 selection: $sectionViewModel.selection,
                                 layout: layout) { bookmark in

            BookmarkCell(applicationModel: applicationModel, bookmark: bookmark)
                .modifier(BorderedSelection())
                .padding(6.0)
                .shadow(color: .shadow, radius: 3.0)

        } contextMenu: { selection in
            sectionViewModel.contextMenu(selection)
        } primaryAction: { selection in
            sectionViewModel.open(.items(selection), browser: settings.browser)
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
        .frame(minWidth: 640, minHeight: 480)
    }

}

#endif
