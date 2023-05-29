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

import Combine
import SwiftUI

import BookmarksCore
import Interact

struct AddTagsView: View {

    private struct LayoutMetrics {
        static let minimumButtonWidth = 80.0
    }

    @Environment(\.dismiss) var dismiss

    @State var isBusy = false
    @AppStorage(SettingsKey.addTagsMarkAsRead.rawValue) var markAsRead: Bool = false

    @State var tokens: [Token<String>] = []

    @ObservedObject var tagsModel: TagsModel
    @ObservedObject var sectionViewModel: SectionViewModel

    init(tagsModel: TagsModel, sectionViewModel: SectionViewModel) {
        self.tagsModel = tagsModel
        self.sectionViewModel = sectionViewModel
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
                    TokenField("Tags", tokens: $tokens) { string, editing in
                        let tag = string.lowercased()
                        return Token(tag)
                            .associatedValue(tag)
                    } completions: { substring in
                        tagsModel.suggestions(prefix: substring,
                                              existing: tokens
                            .filter { !$0.isPartial }
                            .compactMap { $0.associatedValue })
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
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .horizontalSpace(.both)
                        }
                        .frame(minWidth: LayoutMetrics.minimumButtonWidth, maxWidth: .infinity)
                        .keyboardShortcut(.cancelAction)
                        Button {
                            let tags = tokens.compactMap { $0.associatedValue }
                            sectionViewModel.addTags(tags: Set(tags), markAsRead: markAsRead)
                            dismiss()
                        } label: {
                            Text("OK")
                                .horizontalSpace(.both)
                        }
                        .frame(minWidth: LayoutMetrics.minimumButtonWidth, maxWidth: .infinity)
                        .keyboardShortcut(.defaultAction)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .frame(minWidth: 200)
        .padding()
        .disabled(isBusy)
    }

}
