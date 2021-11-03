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

struct AddTagsView: View {
    
    @Environment(\.manager) var manager: BookmarksManager
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var tagsView: TagsView
    var bookmark: Bookmark
    @State var search: String = ""
    @State var tags: [String]
    @State var saving = false
    
    var available: [String] {
        // TODO: Make this async.
        return tagsView.suggestions(prefix: "", existing: tags)
    }
    
    var filteredTags: [String] {
        // TODO: Make this async.
        return tagsView.suggestions(prefix: search, existing: tags)
    }
        
    init(tagsView: TagsView, bookmark: Bookmark) {
        self.tagsView = tagsView
        self.bookmark = bookmark
        _tags = State(initialValue: Array(bookmark.tags))
    }
    
    func save() {
        saving = true
        let bookmark = bookmark.setting(tags: Set(tags))
        manager.updateBookmarks([bookmark]) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    print("Failed to save with error \(error)")
                }
                saving = false
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section("Selected") {
                    if tags.isEmpty {
                        Text("None")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                HStack {
                                    Text(tag)
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Existing") {
                    ForEach(available) { tag in
                        Button {
                            tags.append(tag)
                        } label: {
                            HStack {
                                Text(tag)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .imageScale(.medium)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .foregroundColor(.primary)
            .listStyle(.grouped)
            .overlay {
                if !search.isEmpty {
                    List {
                        ForEach(filteredTags) { tag in
                            Button {
                                tags.append(tag)
                                search = ""
                            } label: {
                                HStack {
                                    Text(tag)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .imageScale(.medium)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    .listStyle(.grouped)
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: save) {
                        Text("Done")
                            .bold()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
}