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

struct EditView: View {
    
    enum SheetType {
        case addTag
    }
    
    @Environment(\.applicationModel) var applicationModel: ApplicationModel
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var tagsModel: TagsModel
    var bookmark: Bookmark
    @State var search: String = ""
    @State var title: String
    @State var toRead: Bool
    @State var shared: Bool
    @State var tags: [String]
    @State var saving = false
    
    @State var sheet: SheetType?
        
    init(tagsModel: TagsModel, bookmark: Bookmark) {
        self.tagsModel = tagsModel
        self.bookmark = bookmark
        _title = State(initialValue: bookmark.title)
        _tags = State(initialValue: Array(bookmark.tags))
        _shared = State(initialValue: bookmark.shared)
        _toRead = State(initialValue: bookmark.toRead)
    }
    
    func save() {
        saving = true
        let bookmark = bookmark
            .setting(title: title)
            .setting(tags: Set(tags))
            .setting(shared: shared)
            .setting(toRead: toRead)
        applicationModel.updateBookmarks([bookmark]) { result in
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
            Form {
                Section {
                    TextField("Title", text: $title)
                }
                Section {
                    Toggle("Unread", isOn: $toRead)
                    Toggle("Public", isOn: $shared)
                }
                Section {
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
                        .foregroundColor(.primary)
                    }
                } header: {
                    HStack {
                        Text("Tags")
                        Spacer()
                        Button {
                            sheet = .addTag
                        } label: {
                            Text("Add...")
                        }
                    }
                }
                Section {
                    Text(bookmark.url.absoluteString)
                }
            }
            .listStyle(.grouped)
            .navigationTitle(bookmark.url.absoluteString)
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
                        Text("Save")
                            .bold()
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .addTag:
                    AddTagView(tagsModel: tagsModel, tags: $tags)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
}
extension EditView.SheetType: Identifiable {
    
    public var id: Self { self }
    
}
