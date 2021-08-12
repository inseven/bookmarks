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

struct MainWindow: View {

    enum SheetType {
        case addTags(items: [Item])
    }

    typealias SheetHandler = (SheetType) -> Void

    struct SheetHandlerEnvironmentKey: EnvironmentKey {
        static var defaultValue: MainWindow.SheetHandler = { _ in }
    }

    @Environment(\.manager) var manager: BookmarksManager

    @Binding var selection: BookmarksSection?

    @State var sheet: SheetType? = nil

    var body: some View {
        NavigationView {
            Sidebar(tagsView: manager.tagsView, settings: manager.settings, selection: $selection)
            ContentView(sidebarSelection: $selection, database: manager.database)
        }
        .environment(\.sheetHandler, { sheet in
            self.sheet = sheet
        })
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .addTags(let items):
                AddTagsView(tagsView: manager.tagsView, items: items)
            }
        }
        .handlesError()
        .observesApplicationFocus()
        .frameAutosaveName("Main Window")
    }

}

extension MainWindow.SheetType: Identifiable {

    var id: String {
        switch self {
        case .addTags(let items):
            return "addTags:\(items.map { $0.identifier }.joined(separator: ","))"
        }
    }

}

extension EnvironmentValues {

    var sheetHandler: (MainWindow.SheetHandler) {
        get { self[MainWindow.SheetHandlerEnvironmentKey.self] }
        set { self[MainWindow.SheetHandlerEnvironmentKey.self] = newValue }
    }
    
}
