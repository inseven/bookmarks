// Copyright (c) 2020-2025 Jason Morley
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

struct EditorView: View {

    @EnvironmentObject var extensionModel: ShareExtensionModel

    @Binding var post: Pinboard.Post

    var body: some View {
        Section {
            TextField("Title", text: $post.description, axis: .vertical)
            TextField("Notes", text: $post.extended, axis: .vertical)
                .lineLimit(5...10)
        }
        Section {
            TokenView("Add tags...", tokens: $post.tags) { candidate, existing, count in
                return extensionModel.tagsModel.suggestions(candidate: candidate, existing: existing, count: count)
            }
        }
        if let url = post.href {
            Section {
                Link(destination: url) {
                    Text(url.absoluteString)
                        .multilineTextAlignment(.leading)
                }
            } header: {

            } footer: {
                if let time = post.time {
                    Text("Created \(time.formatted())")
                }
            }
        }
    }

}
