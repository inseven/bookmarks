// Copyright (c) 2020-2024 InSeven Limited
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

struct Confirmation {

    let title: String
    let role: ButtonRole?
    let actionTitle: String?
    let message: String?
    let action: () -> Void

    init(_ title: String,
         role: ButtonRole? = nil,
         actionTitle: String = "OK",
         message: String? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.actionTitle = actionTitle
        self.message = message
        self.action = action
    }

    init(_ title: String,
         role: ButtonRole? = nil,
         actionTitle: String = "OK",
         message: String? = nil,
         action: @escaping () async -> Void) {
        self.init(title, role: role, actionTitle: actionTitle, message: message) {
            Task {
                await action()
            }
        }
    }

}
