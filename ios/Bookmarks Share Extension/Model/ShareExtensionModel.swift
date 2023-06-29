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
import UniformTypeIdentifiers

import Interact

import BookmarksCore

// TODO: MainActor assertions
class ShareExtensionModel: ObservableObject, Runnable {

    static let shared = ShareExtensionModel()

    @Published var items: [NSExtensionItem] = []
    @MainActor @Published var urls: [URL] = []
    @MainActor @Published var url: URL? = nil
    @MainActor @Published var error: Error? = nil
    @MainActor @Published var post: Pinboard.Post? = nil

    @MainActor private var cancellables: Set<AnyCancellable> = []

    let pinboard: Pinboard? = {
        let settings = Settings()
        guard let apiKey = settings.pinboardApiKey else {
            return nil
        }
        return Pinboard(token: apiKey)
    }()

    @MainActor var extensionContext: NSExtensionContext? = nil {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
                return
            }
            urls = []
            extensionItems
                .compactMap { $0.attachments }
                .reduce([], +)
                .filter { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
                .forEach { itemProvider in
                    itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) { object, error in
                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }
                            guard let url = object as? URL else {
                                return
                            }
                            self.urls.append(url)
                        }
                    }
                }
        }
    }

    init() {

    }

    @MainActor func start() {

        // Get the first URL.
        $urls
            .map { $0.first }
            .receive(on: DispatchQueue.main)
            .assign(to: \.url, on: self)
            .store(in: &cancellables)

        // Create the post with initial values.
        $url
            .compactMap { $0 }
            .asyncMap { url in
                do {
                    let title = try await url.title()
                    return Pinboard.Post(href: url, description: title ?? "")
                } catch {
                    print("Failed to get contents with error \(error).")
                    // TODO:
                    return nil
                }
            }
            .assign(to: \.post, on: self)
            .store(in: &cancellables)

    }

    @MainActor func stop() {
        cancellables.removeAll()
    }


    // TODO: Get the page title; can I do this from the share item?

    @MainActor func save(toRead: Bool = false) {
        guard let pinboard,
              var post else {
            // TODO: This should be an error.
            return
        }
        post.toRead = toRead
        Task {
            do {
                _ = try await pinboard.postsAdd(post)
                await MainActor.run {
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }

    @MainActor func dismiss() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    @MainActor func cancel() {
        extensionContext?.cancelRequest(withError: CancellationError())
    }

}
