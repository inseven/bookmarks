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

    @State var tokens: [String] = []

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
                    TokenView("Add tags...", tokens: $tokens) { candidate in
                        return tagsModel.suggestions(prefix: candidate, existing: tokens)
                            .sorted()
                            .prefix(1)
                            .sorted()
                    }
                    .frame(minWidth: 400, minHeight: 100)
                    Divider()
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
                            sectionViewModel.addTags(tags: Set(tokens), markAsRead: markAsRead)
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
