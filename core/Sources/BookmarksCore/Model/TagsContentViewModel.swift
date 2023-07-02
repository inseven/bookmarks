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

class TagsContentViewModel: ObservableObject, Runnable {

    var applicationModel: ApplicationModel

    @MainActor @Published var tags: [Database.Tag] = []
    @MainActor @Published var filter = ""
    @MainActor @Published var filteredTags: [Database.Tag] = []
    @MainActor @Published var selection: Set<String> = []
    @MainActor @Published var confirmation: Confirmation? = nil
    @MainActor @Published var error: Error? = nil

    @MainActor var tagsModel: TagsModel
    @MainActor var cancellables: Set<AnyCancellable> = []

    init(applicationModel: ApplicationModel) {
        self.applicationModel = applicationModel
        self.tagsModel = applicationModel.tagsModel
    }

    @MainActor func start() {
        tagsModel.$tags
            .combineLatest($filter)
            .receive(on: DispatchQueue.global())
            .map { tags, filter in
                guard !filter.isEmpty else {
                    return tags
                }
                return tags.filter { $0.name.localizedCaseInsensitiveContains(filter) }
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

    @MainActor private func tags(_ scope: SelectionScope<String>) -> Set<String> {
        switch scope {
        case .items(let items):
            return items
        case .selection:
            // Counter-intuitively, we need to generate the intersection of our tags and the current visible filtered
            // tags as SwiftUI doesn't update the selection set as the items in the list change when filtering. It might
            // be cleaner to update the selection ourselves as the list is filtered, but doing it here we avoid thinking
            // too hard about race conditions and only do work when we need the selection updated.
            let visibleTags = Set(filteredTags.map { $0.name })
            return selection
                .filter { visibleTags.contains($0) }
        }
    }

    @MainActor func delete(tags scope: SelectionScope<String>) {
        let tags = tags(scope)
        let title: String
        if tags.count < 5 {
            let summary = tags
                .sorted()
                .map { "'\($0)'" }
                .formatted(.list(type: .and))
            title = "Delete \(summary)?"
        } else {
            title = "Delete \(tags.count) Tags?"
        }
        confirmation = Confirmation(title,
                                    role: .destructive,
                                    actionTitle: "Delete",
                                    message: "No bookmarks will be deleted as part of this operation.") {
            do {
                try await self.applicationModel.delete(tags: Array(tags))
            } catch {
                self.error = error
            }
        }
    }

    @MainActor func open(tags scope: SelectionScope<String>) {
        let tags = tags(scope)
        guard tags.count == 1,
              let tag = tags.first,
              let actionURL = URL(forOpeningTag: tag) else {
            return
        }
        Application.open(actionURL)
    }

}
