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

#if os(macOS)

import Combine
import SwiftUI

import Interact

class ItemViewModel: ObservableObject, Runnable {

    let extensionModel: SafariExtensionModel
    let pinboard: Pinboard

    let tab: Tab

    @Published var isLoading: Bool = true
    @Published var title: String = ""
    @Published var post: Pinboard.Post? = nil
    @Published var suggestions: [String] = []

    @Published var tokens: [String] = []

    var cancellables: [AnyCancellable] = []

    init(extensionModel: SafariExtensionModel, pinboard: Pinboard, tab: Tab) {
        self.extensionModel = extensionModel
        self.pinboard = pinboard
        self.tab = tab
        self.title = tab.title
    }

    func start() {

        // Fetch the document.
        Task {
            do {
                let result = try await pinboard.postsGet(url: tab.url)
                if let post = result.posts.first {
                    DispatchQueue.main.async {
                        self.post = post
                        self.title = post.description
                        self.tokens = post.tags
                    }
                }
            } catch {
                print("Failed to fetch data with error \(error).")
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

    }

    func stop() {
        cancellables = []
    }

    func save() {
        Task {
            do {
                if var post = post {
                    post.description = title
                    post.tags = tokens
                    _ = try await pinboard.postsAdd(post)
                    DispatchQueue.main.async {
                        self.extensionModel.close(self.tab)
                    }
                } else {
                    let post = Pinboard.Post(href: self.tab.url,
                                             description: title,
                                             tags: tokens)
                    _ = try await pinboard.postsAdd(post)
                    DispatchQueue.main.async {
                        self.extensionModel.close(self.tab)
                    }
                }
            } catch {
                print("Failed to save post with error \(error).")
            }
        }
    }

    func close() {
        withAnimation {
            extensionModel.close(tab)
        }
    }

    func remove() {
        withAnimation {
            extensionModel.close(tab)
        }
    }

    func activate() {
        extensionModel.activate(tab)
    }

}

#endif
