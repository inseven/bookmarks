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


struct SelectionSheetHandler: ViewModifier {

    struct IdentifiableError: Identifiable {

        var id = UUID()
        var error: Error

    }

    @Environment(\.manager) var manager

    @ObservedObject var selection: BookmarksSelection

    @State var error: IdentifiableError? = nil

    func body(content: Content) -> some View {
        content
            .sheet(item: $selection.sheet) { sheet in
                switch sheet {
                case .addTags(let items):
                    AddTagsView(tagsView: manager.tagsView, items: items)
                }
            }
            .alert(item: $error) { error in
                return Alert(title: Text("Error"), message: Text(error.error.localizedDescription))
            }
            .onReceive(selection.$lastError) { error in
                guard let error = error else {
                    return
                }
                self.error = IdentifiableError(error: error)
            }
    }

}

extension View {

    func handlesSelectionSheets(_ selection: BookmarksSelection) -> some View {
        modifier(SelectionSheetHandler(selection: selection))
    }

}
