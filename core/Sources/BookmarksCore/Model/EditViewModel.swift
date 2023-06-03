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

import Interact

public class EditViewModel: ObservableObject, Runnable {

    public enum State {
        case uninitialized
        case loading
        case ready
    }

    @MainActor @Published public var state: State = .uninitialized
    @MainActor @Published public var error: Error? = nil

    @MainActor @Published public var title: String = ""
    @MainActor @Published public var toRead: Bool = false
    @MainActor @Published public var shared: Bool = false
    @MainActor @Published public var tags: [String] = []

    @MainActor @Published private var bookmark: Bookmark?

    let applicationModel: ApplicationModel
    let id: String

    private var cancellables: Set<AnyCancellable> = []

    public init(applicationModel: ApplicationModel, id: String) {
        self.applicationModel = applicationModel
        self.id = id
    }

    @MainActor public func start() {

        // Load the bookmark from the database.
        if state == .uninitialized {
            state = .loading
            Task {
                do {
                    let bookmark = try await applicationModel.database.bookmark(identifier: id)
                    await MainActor.run {
                        self.bookmark = bookmark
                        self.state = .ready
                        self.title = bookmark.title
                        self.shared = bookmark.shared
                        self.toRead = bookmark.toRead
                        self.tags = Array(bookmark.tags.sorted())
                    }
                } catch {
                    await MainActor.run {
                        self.error = error
                    }
                }
            }
        }

        // Watch for changes and publish updates.
        // N.B. This drops the first values to ensure we don't update the bookmark with temporary values.
        $title
            .combineLatest($shared, $toRead, $tags)
            .dropFirst()
            .combineLatest($bookmark
                .compactMap { $0 })
            .debounce(for: 1, scheduler: DispatchQueue.global())
            .sink { [weak self] group, bookmark in
                let (title, shared, toRead, tags) = group
                guard let self,
                      bookmark.title != title || bookmark.shared != shared || bookmark.toRead != toRead || bookmark.tags != Set(tags)
                else {
                    return
                }
                let update = bookmark
                    .setting(title: title)
                    .setting(shared: shared)
                    .setting(toRead: toRead)
                    .setting(tags: Set(tags))
                self.applicationModel.updateBookmarks([update]) { result in
                    DispatchQueue.main.async {
                        if case let .failure(error) = result {
                            self.error = error
                        }
                    }
                }
            }
            .store(in: &cancellables)

    }

    @MainActor public func stop() {
        cancellables.removeAll()
    }

}
