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

import Combine
import SwiftUI

import Interact
import WrappingHStack

class TokenViewModel: ObservableObject, Runnable {

    struct Token: Identifiable {

        let id = UUID()
        let text: String

        init(_ text: String) {
            self.text = text
        }

    }

    @Binding var tokens: [String]

    @Published var items: [Token] = []
    @Published var input: String = ""
    @Published var suggestions: [String] = []

    let suggestion: (String, [String], Int) -> [String]
    var cancellables: [AnyCancellable] = []

    init(tokens: Binding<[String]>, suggestion: @escaping (String, [String], Int) -> [String]) {
        self._tokens = tokens
        self.suggestion = suggestion
        self.items = tokens.wrappedValue
            .map { Token($0) }
    }

    func start() {

        $input
            .receive(on: DispatchQueue.main)
            .filter { $0.containsWhitespaceAndNewlines() }
            .sink { [weak self] tags in
                guard let self else { return }
                self.commit()
            }
            .store(in: &cancellables)

        $input
            .combineLatest($items)
            .receive(on: DispatchQueue.main)
            .map { [suggestion] input, items in
                return suggestion(input, items.map({ $0.text }), 8)
            }
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)

        $items
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .map { $0.map { $0.text } }
            .assign(to: \.tokens, on: self)
            .store(in: &cancellables)
    }

    func stop() {
        cancellables = []
    }

    func commit() {
        let tags = input
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        for tag in tags {
            self.items.append(Token(tag))
        }
        input = ""
    }

    @MainActor func acceptSuggestion(_ token: String) {
        items.append(TokenViewModel.Token(token))
        input = ""
    }

    func deleteBackwards() {
        guard !items.isEmpty else {
            return
        }
        items.removeLast()
    }

}
