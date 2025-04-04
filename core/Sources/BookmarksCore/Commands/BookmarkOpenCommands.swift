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

struct BookmarkOpenCommands: View {

    @EnvironmentObject var settings: Settings

    @ObservedObject var sectionViewModel: SectionViewModel

    var body: some View {

        Button(LocalizedString("BOOKMARK_MENU_TITLE_OPEN")) {
            sectionViewModel.open(.selection, browser: settings.browser)
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(sectionViewModel.selection.isEmpty)

        Divider()

        Button(LocalizedString("BOOKMARK_MENU_TITLE_PREVIEW")) {
            sectionViewModel.showPreview()
        }
        .keyboardShortcut(.space, modifiers: [])
        .disabled(sectionViewModel.selection.isEmpty)

        Divider()

        Button(LocalizedString("BOOKMARK_MENU_TITLE_VIEW_ON_INTERNET_ARCHIVE")) {
            sectionViewModel.open(.selection, location: .internetArchive, browser: settings.browser)
        }
        .keyboardShortcut(.return, modifiers: [.command, .shift])
        .disabled(sectionViewModel.selection.isEmpty)

    }

}
