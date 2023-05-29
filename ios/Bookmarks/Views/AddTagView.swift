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

extension String {
    
    func replacingCharacters(in characterSet: CharacterSet, with replacement: String) -> String {
         components(separatedBy: characterSet)
             .filter { !$0.isEmpty }
             .joined(separator: replacement)
     }
    
    var safeKeyword: String {
         lowercased()
             .replacingOccurrences(of: ".", with: "")
             .replacingCharacters(in: CharacterSet.letters.inverted, with: " ")
             .trimmingCharacters(in: CharacterSet.whitespaces)
             .replacingCharacters(in: CharacterSet.whitespaces, with: "-")
     }
    
}

struct AddTagView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var tagsModel: TagsModel
    @Binding var tags: [String]
    @State var search: String = ""
    @FocusState private var isFocused: Bool
    
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
                Section {
                    TextField("Tag", text: $search)
                        .focused($isFocused)
                }
                if !search.isEmpty && !tags.contains(search.safeKeyword) {
                    Section("Suggested") {
                        Button {
                            tags.append(search.safeKeyword)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            AddTagLabel(search.safeKeyword)
                        }
                    }
                }
                Section(search.isEmpty ? "Tags" : "Matching Tags") {
                    ForEach(filteredTags) { tag in
                        Button {
                            tags.append(tag)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            AddTagLabel(tag)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Cancel")
            })
        }
        .navigationViewStyle(.stack)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isFocused = true
            }
        }

    }
    
}
