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

import Combine
import SwiftUI

import BookmarksCore
import Interact

struct AddTagsView: View {

    @Environment(\.manager) var manager
    @Environment(\.selection) var selection

    @Environment(\.presentationMode) var presentationMode

    var items: [Item]
    @State var isBusy = false
    @AppStorage(SettingsKey.addTagsMarkAsRead.rawValue) var markAsRead: Bool = false

    @State var tokens: [Token<String>] = []

    @ObservedObject var tagsView: TagsView

    init(tagsView: TagsView, items: [Item]) {
        self.tagsView = tagsView
        self.items = items
    }

    var characterSet: CharacterSet {
        let characterSet = NSTokenField.defaultTokenizingCharacterSet
        let spaceCharacterSet = CharacterSet(charactersIn: " \n")
        return characterSet.union(spaceCharacterSet)
    }

    var body: some View {
        Form {
            Section() {
                VStack(alignment: .leading, spacing: 16) {
                    TokenField("Add tags...", tokens: $tokens) { string, editing in
                        let tag = string.lowercased()
                        return Token(tag)
                            .associatedValue(tag)
                    } completions: { substring in
                        tagsView.tags(prefix: substring)
                    }
                    .tokenizingCharacterSet(characterSet)
                    .font(.title)
                    .frame(minWidth: 400)
                    Toggle("Mark as read", isOn: $markAsRead)
                }
                HStack(spacing: 8) {
                    Spacer()
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .controlSize(.small)
                    }
                    HStack {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                        Button("OK") {
                            isBusy = true
                            let tags = tokens.compactMap { $0.associatedValue }
                            let updatedItems = items.map { item in
                                item
                                    .adding(tags: Set(tags))
                                    .setting(toRead: markAsRead ? false : item.toRead)
                            }
                            selection.update(manager: manager, items: updatedItems) { result in
                                DispatchQueue.main.async {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .frame(minWidth: 200)
        .padding()
        .disabled(isBusy)
    }

}
