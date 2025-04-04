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

import SwiftUI

public struct SelectionToolbar: CustomizableToolbarContent {

    struct Content: CustomizableToolbarContent {

        @EnvironmentObject var settings: Settings

        @ObservedObject var sectionViewModel: SectionViewModel

        var body: some CustomizableToolbarContent {

            ToolbarItem(id: "preview") {
                Button {
                    sectionViewModel.showPreview()
                } label: {
                    Label("Preview", systemImage: "eye")
                }
                .help("Preview with Quick Look")
                .keyboardShortcut(.space, modifiers: [])
                .disabled(sectionViewModel.selection.count != 1)
            }

            ToolbarItem(id: "open") {
                Button {
                    sectionViewModel.open(.selection, browser: settings.browser)
                } label: {
                    Label("Open", systemImage: "safari")
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(sectionViewModel.selection.isEmpty)
            }

            ToolbarItem(id: "delete") {
                Button {
                    await sectionViewModel.delete(.selection)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete")
                .disabled(sectionViewModel.selection.isEmpty)
            }

            ToolbarItem(id: "share") {
                ShareLink(items: sectionViewModel.selectionURLs) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(sectionViewModel.selectionURLs.isEmpty)
            }

        }

    }

    @FocusedObject var sectionViewModel: SectionViewModel?

    public init() {

    }

    public var body: some CustomizableToolbarContent {
        Content(sectionViewModel: sectionViewModel ?? SectionViewModel())
    }

}
