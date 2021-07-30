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

struct RenameTagView: View {

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.manager) var manager: BookmarksManager
    @State var tag: String
    @State var isBusy = false

    @State var newTag: String = ""

    init(tag: String) {
        _tag = State(initialValue: tag)
        _newTag = State(initialValue: tag)
    }

    // TODO: Default focus when launching.
    var body: some View {
        Form {
            Section(header: Text("Rename Tag")) {
                TextField("Tag name", text: $newTag)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("OK") {
                        isBusy = true
                        manager.pinboard.tagsRename(tag, to: newTag) { result in
                            switch result {
                            case .failure(let error):
                                // TODO: Report the error
                                print("Failed to rename tag with error \(error)")
                                isBusy = false
                            case .success:
                                print("Successfully renamed tag")
                                manager.refresh()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 200)
        .padding()
        .disabled(isBusy)
    }

}
