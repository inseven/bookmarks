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

import SwiftUI

public enum DismissableAction {
    case close
    case done
    case cancel
}

struct Dismissable: ViewModifier {

    @Environment(\.dismiss) var dismiss

    let action: DismissableAction

    var placement: ToolbarItemPlacement {
        switch action {
        case .close:
            return .cancellationAction
        case .done:
            return .confirmationAction
        case .cancel:
            return .cancellationAction
        }
    }

    var text: String {
        switch action {
        case .close:
            return "Close"
        case .done:
            return "Done"
        case.cancel:
            return "Cancel"
        }
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: placement) {
                    Button {
                        dismiss()
                    } label: {
                        Text(text)
                    }
                }
            }
    }

}

extension View {

    public func dismissable(_ action: DismissableAction) -> some View {
        return modifier(Dismissable(action: action))
    }

}
