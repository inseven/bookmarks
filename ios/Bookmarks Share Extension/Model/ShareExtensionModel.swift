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

protocol ShareExtensionDataSource: NSObject {

    var extensionContext: NSExtensionContext? { get }

}

// TODO: MainActor assertions
class ShareExtensionModel: ObservableObject, Runnable {

    @Published var items: [NSExtensionItem] = []
    @MainActor @Published var error: Error? = nil
    @MainActor @Published var post: Pinboard.Post? = nil

    @MainActor private var cancellables: Set<AnyCancellable> = []

    private static let database: Database = {
        try! Database(path: Database.sharedStoreURL)
    }()

    let tagsModel: TagsModel

    weak var dataSource: ShareExtensionDataSource? = nil

    var pinboard: Pinboard? {
        let settings = Settings()
        guard let apiKey = settings.pinboardApiKey else {
            return nil
        }
        return Pinboard(token: apiKey)
    }

    init() {
        self.tagsModel = TagsModel(database: Self.database)
        tagsModel.start()
    }

    @MainActor func load() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let extensionItem = dataSource?.extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first
        else {
            return
        }
        Task {
            guard let url = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL else {
                return
            }
            if let post = try await pinboard?.postsGet(url: url).posts.first {
                await MainActor.run {
                    self.post = post
                }
            } else {
                let title = try await url.title() ?? ""
                await MainActor.run {
                    self.post = Pinboard.Post(href: url, description: title, time: nil)
                }
            }
        }
    }

    @MainActor func start() {

    }

    @MainActor func stop() {
        cancellables.removeAll()
    }

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
        dataSource?.extensionContext?.completeRequest(returningItems: nil)
    }

    @MainActor func cancel() {
        dataSource?.extensionContext?.cancelRequest(withError: CancellationError())
    }

}
