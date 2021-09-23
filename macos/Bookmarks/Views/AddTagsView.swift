// Copyright (c) 2020-2021 InSeven Limited
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

import BookmarksCore
import Interact

struct TestWrappedLayout<Content: View, Element: Identifiable & Equatable>: View {

//    @State var platforms = ["Ninetendo", "XBox", "PlayStation", "PlayStation 2", "PlayStation 3", "PlayStation 4"]

    var items: [Element]
    var content: (Element) -> Content

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items) { platform in
                content(platform)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width)
                        {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if platform == items.last! {
                            width = 0 //last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: {d in
                        let result = height
                        if platform == items.last! {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
    }

}

extension Set {

    mutating func extend(_ items: [Element]) {
        for item in items {
            self.insert(item)
        }
    }

    mutating func extend(_ items: Set<Element>) {
        extend(Array(items))
    }

}

class Suggestions: ObservableObject {

    @Published var suggestions: Set<String> = Set()

    var pinboard: Pinboard
    var url: URL
    var running = false

    init(manager: BookmarksManager, url: URL) {
        self.pinboard = Pinboard(token: manager.settings.pinboardApiKey)
        self.url = url
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !running else {
            return
        }
        running = true

        _ = Task.detached(priority: .background) {
            do {
                let document = try await self.url.document()
                let keywords = document.keywords
                let tags = document.tags
                DispatchQueue.main.async {
                    self.suggestions.extend(keywords.tags + tags.tags)
                }
                print("keywords = \(keywords)")
            } catch {
                print("failed to fetch keywords with error \(error)")
            }
        }

        pinboard.postsSuggest(url: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let suggestions):
                    self.suggestions.extend(suggestions.recommended.tags)
                    self.suggestions.extend(suggestions.popular.tags)
                    print(self.suggestions)
                case .failure(let error):
                    print("failed to get suggestions with error \(error)")
                }
            }
        }

    }

}

extension Array where Element: Token<String> {

    func contains(_ string: String) -> Bool {
        first { $0.title == string } != nil
    }

}

extension Array where Element == String {

    var tags: [String] {
        self.map { $0.safeKeyword }
    }

}

extension Set where Element == String {

    var tags: [String] {
        Array(self).tags
    }

}

struct ToggleTag: ButtonStyle {

    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(enabled ? Color.accentColor : Color.controlBackground)
            .foregroundColor(enabled ? .white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct AddTagsView: View {

    @Environment(\.manager) var manager
    @Environment(\.selection) var selection

    @Environment(\.presentationMode) var presentationMode

    var bookmarks: [Bookmark]
    @State var isBusy = false
    @AppStorage(SettingsKey.addTagsMarkAsRead.rawValue) var markAsRead: Bool = false

    @State var tokens: [Token<String>] = []

    @ObservedObject var tagsView: TagsView
    @StateObject var suggester: Suggestions

    init(tagsView: TagsView, bookmarks: [Bookmark], manager: BookmarksManager) {
        self.tagsView = tagsView
        self.bookmarks = bookmarks
        _suggester = StateObject(wrappedValue: Suggestions(manager: manager, url: bookmarks.first!.url))
    }

    var characterSet: CharacterSet {
        let characterSet = NSTokenField.defaultTokenizingCharacterSet
        let spaceCharacterSet = CharacterSet(charactersIn: " \n")
        return characterSet.union(spaceCharacterSet)
    }

    var unusedSuggestions: [String] {
        suggester.suggestions.filter { !tokens.contains($0) }
    }

    var body: some View {
        Form {
            Section("Tags") {
                VStack(alignment: .leading, spacing: 16) {
                    TokenField("Add tags...", tokens: $tokens) { string, editing in
                        let tag = string.lowercased()
                        return Token(tag)
                            .associatedValue(tag)
                    } completions: { substring in
                        tagsView.suggestions(prefix: substring,
                                             existing: tokens
                                                .filter { !$0.isPartial }
                                                .compactMap { $0.associatedValue })
                    }
                    .tokenizingCharacterSet(characterSet)
                    .font(.title)
                }
            }
            Section("Favourite Tags") {
                TestWrappedLayout(items: manager.settings.favoriteTags) { suggestion in
                    Button {
                        if tokens.contains(suggestion) {
                            tokens.removeAll { $0.title == suggestion }
                        } else {
                            tokens.append(Token(suggestion))
                        }
                    } label: {
                        Text(suggestion)
                    }
                    .buttonStyle(ToggleTag(enabled: tokens.contains(suggestion)))
                }
            }
            Section("Suggested Tags") {
                TestWrappedLayout(items: suggester.suggestions.sorted()) { suggestion in
                    Button {
                        if tokens.contains(suggestion) {
                            tokens.removeAll { $0.title == suggestion }
                        } else {
                            tokens.append(Token(suggestion))
                        }
                    } label: {
                        Text(suggestion)
                    }
                    .buttonStyle(ToggleTag(enabled: tokens.contains(suggestion)))
                }
            }
            Spacer()
            Section {
                Toggle("Mark as read", isOn: $markAsRead)
                HStack(spacing: 8) {
                    Spacer()
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .controlSize(.small)
                    }
                    HStack {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                        Button("OK") {
                            isBusy = true
                            let tags = tokens.compactMap { $0.associatedValue }
                            let updatedBookmarks = bookmarks.map { item in
                                item
                                    .adding(tags: Set(tags))
                                    .setting(toRead: markAsRead ? false : item.toRead)
                            }
                            selection.update(manager: manager, bookmarks: updatedBookmarks) { result in
                                DispatchQueue.main.async {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 400)
        .padding()
        .background(.ultraThinMaterial)
        .disabled(isBusy)
        .onAppear {
            suggester.start()
        }
    }

}
