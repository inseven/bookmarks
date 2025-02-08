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

#if os(macOS)

import SwiftUI

struct MacLogInView: View {

    @Environment(\.openURL) var openURL

    @EnvironmentObject var applicationModel: ApplicationModel

    @State var username: String = ""
    @State var password: String = ""

    func submit() {
        dispatchPrecondition(condition: .onQueue(.main))
        applicationModel.authenticate(username: username, password: password) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                DispatchQueue.main.async {
                    // TODO: Show this error.
                    print("failed with error \(error)")
                }
            }
        }
    }

    func createAccount() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let url = URL(string: "https://pinboard.in/signup/") else {
            return
        }
        openURL(url)
    }

    var body: some View {
        VStack {
            Image("PinboardLogo")
                .resizable()
                .frame(width: 64, height: 64)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Sign in to Pinboard")
                .bold()
                .frame(maxWidth: .infinity)
            Spacer()
            Form {
                TextField("Username:", text: $username)
                SecureField("Password:", text: $password)
                    .onSubmit(submit)
            }
            Text("Your username and password are used to access your Pinboard API token and are not stored. You can reset your Pinboard API token anytime from the Pinboard website.")
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            VStack {
                Button(action: submit) {
                    Text("Log In").frame(maxWidth: 300)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                Button(action: createAccount) {
                    Text("Create Account").frame(maxWidth: 300)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)

        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400, minHeight: 300, idealHeight: 340)
    }

}

#endif
