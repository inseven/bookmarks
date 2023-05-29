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

import SwiftUI

import BookmarksCore

struct EditTagsView: View {

    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var tagsModel: TagsModel
    @Binding var tags: [String]
    @State var search: String = ""
    
    var available: [String] {
        // TODO: Make this async.
        return tagsModel.suggestions(prefix: "", existing: tags)
    }
    
    var filteredTags: [String] {
        // TODO: Make this async.
        return tagsModel.suggestions(prefix: search, existing: tags)
    }
    
    var body: some View {
        NavigationView {
            List {
                if search.isEmpty {
                    Section {
                        if tags.isEmpty {
                            Text("None")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(tags.sorted()) { tag in
                                TagActionButton(tag, role: .destructive) {
                                    withAnimation {
                                        tags.removeAll { $0 == tag }
                                    }
                                }
                            }
                        }
                    }
                }
                if !search.isEmpty && !tags.contains(search.safeKeyword) {
                    Section("Suggested") {
                        TagActionButton(search.safeKeyword) {
                            withAnimation {
                                tags.append(search.safeKeyword)
                                search = ""
                            }
                        }
                    }
                }
                if !filteredTags.isEmpty {
                    Section(search.isEmpty ? "All Tags" : "Matching Tags") {
                        ForEach(filteredTags) { tag in
                            TagActionButton(tag) {
                                withAnimation {
                                    tags.append(tag)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $search)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                    }
                }

            }
        }
        .navigationViewStyle(.stack)
    }
    
}
