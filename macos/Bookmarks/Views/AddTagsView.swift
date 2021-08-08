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

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.manager) var manager: BookmarksManager
    var items: [Item]
    @State var isBusy = false

    @State var tokens: [Token<String>] = []  // TODO: Support a payload on the tokens.

    @StateObject var tagsView: TagsView
    @State var trie = Trie()

    init(database: Database, items: [Item]) {
        _tagsView = StateObject(wrappedValue: TagsView(database: database))
        self.items = items
    }

    var characterSet: CharacterSet {
        let characterSet = NSTokenField.defaultTokenizingCharacterSet
        let spaceCharacterSet = CharacterSet(charactersIn: " ")
        return characterSet.union(spaceCharacterSet)
    }

    // TODO: Default focus when launching.
    var body: some View {
        Form {
            Section {
                TokenField("Add tags...", tokens: $tokens) { string in
                    let tag = string.lowercased()
                    return Token(tag)
                        .associatedValue(tag)
                } completions: { substring in
                    trie.findWordsWithPrefix(prefix: substring)
                }
                .tokenizingCharacterSet(characterSet)
                .font(.title)
                .frame(minWidth: 400)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("OK") {
                        isBusy = true
                        let tags = tokens.compactMap { $0.associatedValue }
                        for item in items {
                            let item = item
                                .adding(tags: Set(tags))
                                .setting(toRead: false)  // TODO: This is a hack that should be removed (maybe make it an option?)
                            manager.updateItem(item, completion: { _ in })
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 200)
        .padding()
        .disabled(isBusy)
        .onAppear {
            tagsView.start()
        }
        .onDisappear {
            tagsView.stop()
        }
        .onReceive(tagsView.$tags) { tags in
            DispatchQueue.global(qos: .background).async {
                let trie = Trie()
                for tag in tags {
                    trie.insert(word: tag)
                }
                DispatchQueue.main.async {
                    self.trie = trie
                }
            }
        }

    }

}
