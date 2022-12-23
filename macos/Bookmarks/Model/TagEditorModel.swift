// Copyright (c) 2020-2022 InSeven Limited
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

import BookmarksCore

class TagEditorModel: ObservableObject, Runnable {

    @MainActor @Published var tags: [String] = []
    @MainActor @Published var filter = ""
    @MainActor @Published var filteredTags: [String] = []
    @MainActor @Published var selection: Set<String> = []

    @MainActor var tagsView: TagsView
    @MainActor var cancellables: Set<AnyCancellable> = []

    init(tagsView: TagsView) {
        self.tagsView = tagsView
    }

    @MainActor func start() {
        tagsView.$tags
            .combineLatest($filter)
            .receive(on: DispatchQueue.global())
            .map { tags, filter in
                guard !filter.isEmpty else {
                    return tags
                }
                return tags.filter { $0.localizedCaseInsensitiveContains(filter) }
            }
            .receive(on: DispatchQueue.main)
            .sink { filteredTags in
                self.filteredTags = filteredTags
            }
            .store(in: &cancellables)
    }

    @MainActor func stop() {
        cancellables.removeAll()
    }

}
