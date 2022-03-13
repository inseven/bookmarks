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

import SwiftUI

/**
 Disables a view if the `mainMenu` environment variable is equal to `.main` (indicating the view is in the main menu)
 and the `collection` (conforming to Countable`) satisfies the specified condition.

 This shouldn't be required, but allows us to disable the disabling behaviour on the context menu, which is unhappy
 if a stage change occurs to change the disabled state while the context menu is being shown.
 */
struct MainMenuItemConditional: ViewModifier {

    enum Condition {
        case nonEmpty
        case count(Int)
    }

    @Environment(\.menuType) var menuType

    var condition: Condition
    var collection: Countable

    init(condition: Condition, collection: Countable) {
        self.condition = condition
        self.collection = collection
    }

    var isMainMenu: Bool {
        menuType == .main
    }

    var satisfiesCondition: Bool {
        switch condition {
        case .nonEmpty:
            return !collection.isEmpty
        case .count(let count):
            return collection.count == count
        }
    }

    func body(content: Content) -> some View {
        content
            .disabled(isMainMenu && !satisfiesCondition)
    }

}

extension View {

    func mainMenuItemCondition(_ condition: MainMenuItemConditional.Condition, _ collection: Countable) -> some View {
        modifier(MainMenuItemConditional(condition: condition, collection: collection))
    }

}
