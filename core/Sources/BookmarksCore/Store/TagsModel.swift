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
import Foundation

public class TagsModel: ObservableObject {

    @MainActor @Published public var tags: [Database.Tag] = []
    @MainActor @Published public var counts: [String: Int] = [:]
    @MainActor @Published public var trie = Trie()
    @MainActor @Published public var error: Error? = nil

    private var database: Database
    private var cancellables: Set<AnyCancellable> = []

    public init(database: Database) {
        self.database = database
    }

    func update() {
        Task {
            do {
                let tags = try await database.tags()
                let trie = Trie(words: tags.map { $0.name })
                let counts = tags.reduce(into: [String: Int]()) { partialResult, tag in
                    partialResult[tag.name] = tag.count
                }
                await MainActor.run {
                    self.tags = tags
                    self.counts = counts
                    self.trie = trie
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }

    public func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        database
            .updatePublisher
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in
                self.update()
            }
            .store(in: &cancellables)
    }

    @MainActor public func stop() {
        cancellables.removeAll()
        self.tags = []
    }

    @MainActor public func suggestions(candidate: String, existing: [String], count: Int) -> [String] {
        let existing = Set(existing)
        return tags(prefix: candidate)
            .sorted { $0.count > $1.count }
            .prefix(count + existing.count)
            .filter { !existing.contains($0.name) }
            .prefix(count)
            .map { $0.name }
    }

    @MainActor private func tags(prefix: String) -> [Database.Tag] {
        return trie.findWordsWithPrefix(prefix: prefix)
            .compactMap { name in
                guard let count = counts[name] else {
                    return nil
                }
                return Database.Tag(name: name, count: count)
            }
    }

}

