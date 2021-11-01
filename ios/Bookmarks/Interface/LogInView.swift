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
import Introspect

struct LogInView: View {

    @Environment(\.manager) var manager
    @Environment(\.presentationMode) var presentationMode

    @State var username: String = ""
    @State var password: String = ""
    @State var authenticating = false

    func submit() {
        dispatchPrecondition(condition: .onQueue(.main))
        authenticating = true
        manager.authenticate(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    // TODO: Show this error.
                    print("failed with error \(error)")
                }
                authenticating = false
            }
        }
    }

    func createAccount() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let url = URL(string: "https://pinboard.in/signup/") else {
            return
        }
        manager.open(url: url, completion: { _ in })
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    SecureField("Password", text: $password)
                        .onSubmit(submit)
                } footer: {
                    Text("Your username and password are used to access your Pinboard API token and are not stored. You can reset your Pinboard API token anytime from the Pinboard website.")
                }
                Button(action: createAccount) {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: submit) {
                Text("Next")
            }.disabled(authenticating))
        }
        .navigationViewStyle(.stack)
        .introspectViewController { navigationController in
            navigationController.isModalInPresentation = true
        }
    }

}
