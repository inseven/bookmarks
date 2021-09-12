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

struct LogInSheet: View {

    @Environment(\.manager) var manager

    @Environment(\.presentationMode) var presentationMode

    @State var username: String = ""
    @State var password: String = ""

    func submit() {
        dispatchPrecondition(condition: .onQueue(.main))
        Pinboard.apiToken(username: username, password: password) { result in
            switch result {
            case .success(let token):
                print("got token \(token)")
            case .failure(let error):
                print("failed with error \(error)")
            }
        }
    }

    func dismiss() {
        dispatchPrecondition(condition: .onQueue(.main))
        presentationMode.wrappedValue.dismiss()
    }

    var body: some View {
        VStack {
            TextField("Username", text: $username, prompt: Text("Username"))
            TextField("Password", text: $password, prompt: Text("Password"))
                .onSubmit(submit)
            HStack {
                Button("Cancel", action: dismiss)
                    .keyboardShortcut(.cancelAction)
                Button("OK", action: submit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

}
