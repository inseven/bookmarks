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

import SwiftUI

import BookmarksCore

protocol Countable {
    var isEmpty: Bool { get }
    var count: Int { get }
}

struct CountDisabling: ViewModifier {

    enum Requirement {
        case nonEmpty
        case count(Int)
    }

    @Environment(\.menuType) var menuType

    var requirement: Requirement
    var collection: Countable

    init(_ requirement: Requirement, collection: Countable) {
        self.requirement = requirement
        self.collection = collection
    }

    var isMainMenu: Bool {
        menuType == .main
    }

    var passesRequirement: Bool {
        switch requirement {
        case .nonEmpty:
            return !collection.isEmpty
        case .count(let count):
            return collection.count == count
        }
    }

    func body(content: Content) -> some View {
        content
            .disabled(isMainMenu && !passesRequirement)
    }

}

extension View {

    func requires(_ requirement: CountDisabling.Requirement, collection: Countable) -> some View {
        modifier(CountDisabling(requirement, collection: collection))
    }

}

extension Set: Countable {

}

struct BookmarkOpenCommands: View {

    @Environment(\.manager) var manager
    @Environment(\.menuType) var menuType

    @ObservedObject var selection: BookmarksSelection

    var body: some View {
        Button("Open") {
            selection.open(manager: manager)
        }
        .contextAwareKeyboardShortcut(.return, modifiers: [.command])
        .requires(.nonEmpty, collection: selection.items)
        Button("Open on Internet Archive") {
            selection.open(manager: manager, location: .internetArchive)
        }
        .contextAwareKeyboardShortcut(.return, modifiers: [.command, .shift])
        .requires(.nonEmpty, collection: selection.items)
    }

}
