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

#if os(iOS)

import SwiftUI

import WrappingHStack

public struct PhoneEditView: View {
    
    enum SheetType: Identifiable {

        public var id: Self {
            return self
        }

        case addTag
    }

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var applicationModel: ApplicationModel
    
    @ObservedObject var tagsModel: TagsModel
    var bookmark: Bookmark
    @State var title: String
    @State var notes: String
    @State var toRead: Bool
    @State var shared: Bool
    @State var tags: [String]
    @MainActor @State var saving = false
    @MainActor @State var error: Error? = nil
    
    @State var sheet: SheetType?
        
    public init(tagsModel: TagsModel, bookmark: Bookmark) {
        self.tagsModel = tagsModel
        self.bookmark = bookmark
        _title = State(initialValue: bookmark.title)
        _notes = State(initialValue: bookmark.notes)
        _tags = State(initialValue: Array(bookmark.tags))
        _shared = State(initialValue: bookmark.shared)
        _toRead = State(initialValue: bookmark.toRead)
    }
    
    @MainActor func save() {
        saving = true
        var update = bookmark
        update.title = title
        update.notes = notes
        update.tags = Set(tags)
        update.shared = shared
        update.toRead = toRead
        Task {
            do {
                try await applicationModel.update(bookmarks: [update])
                dismiss()
            } catch {
                print("Failed to save with error \(error).")
                self.error = error
            }
            saving = false
        }
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(5...10)
                }
                Section {
                    HStack {
                        Toggle("Unread", isOn: $toRead)
                        Divider()
                        Toggle("Public", isOn: $shared)
                    }
                }
                Section {
                    Button {
                        sheet = .addTag
                    } label: {
                        if tags.isEmpty {
                            Text("Add Tags...")
                        } else {
                            WrappingHStack(alignment: .leading) {
                                ForEach(tags.sorted()) { tag in
                                    TagView(tag, color: tag.color())
                                }
                            }
                        }
                    }
                }
                Section {
                    Link(destination: bookmark.url) {
                        Text(bookmark.url.absoluteString)
                    }
                } header: {

                } footer: {
                    Text("Saved \(bookmark.date.formatted())")
                }
            }
            .listStyle(.grouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .bold()
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .addTag:
                    PhoneEditTagsView(tagsModel: tagsModel, tags: $tags)
                }
            }
            .presents($error)
        }
        .navigationViewStyle(.stack)
    }
    
}

#endif
