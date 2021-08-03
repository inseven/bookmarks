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

extension Text {

    init(contentsOf filename: String) {
        guard let path = Bundle.main.path(forResource: filename, ofType: nil),
              let contents = try? String(contentsOfFile: path) else {
            self.init("missing file")
            return
        }
        self.init(contents)
    }

}

struct AboutView: View {

    @Environment(\.presentationMode) var presentationMode

    var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var build: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    var people = [
        "Blake Merryman",
        "Joanne Wong",
        "Lukas Fittl",
        "Pavlos Vinieratos",
        "Sara Frederixon",
        "Sarah Barbour",
        "Terrence Talbot",
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version ?? "")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(build ?? "")
                            .foregroundColor(.secondary)
                    }
                }
                Section(header: Text("InSeven Limited")) {
                    Button("Company") {
                        UIApplication.shared.open(URL(string: "https://inseven.co.uk")!)
                    }
                    Button("Support") {
                        var components = URLComponents()
                        components.scheme = "mailto"
                        components.path = "support@inseven.co.uk"
                        components.queryItems = [URLQueryItem(name: "subject", value: "Bookmarks Support")]
                        UIApplication.shared.open(components.url!)
                    }
                }
                Section(header: Text("With Thanks")) {
                    ForEach(people) { person in
                        Text(person)
                    }
                }
            }
            .navigationBarTitle("About", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .fontWeight(.regular)
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

}
