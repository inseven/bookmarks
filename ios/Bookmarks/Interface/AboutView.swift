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

import Diligence

struct AboutView: View {

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                HeaderSection {
                    IconView(uiImage: UIImage(named: "Icon")!)
                    ApplicationNameHeaderView()
                }
                BuildSection("inseven/bookmarks")
                Section {
                    Link("InSeven Limited", url: URL(string: "https://inseven.co.uk")!)
                    Button {
                        var components = URLComponents()
                        components.scheme = "mailto"
                        components.path = "support@inseven.co.uk"
                        components.queryItems = [URLQueryItem(name: "subject", value: "Bookmarks Support")]
                        guard let url = components.url else {
                            return
                        }
                        UIApplication.shared.open(url)
                    } label: {
                        HStack {
                            Text("Support")
                            Spacer()
                            Image(systemName: "envelope")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .foregroundColor(.primary)
                CreditSection("Contributors", [
                    Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk")),
                ])
                CreditSection("Thanks", [
                    "Blake Merryman",
                    "Joanne Wong",
                    "Lukas Fittl",
                    "Pavlos Vinieratos",
                    "Sara Frederixon",
                    "Sarah Barbour",
                    "Terrence Talbot",
                ])
                LicenseSection("Licenses", [
                    License(name: "Binding+mappedToBool", author: "Joseph Duffy", filename: "Binding+mappedToBool"),
                    License(name: "Diligence", author: "InSeven Limited", filename: "Diligence"),
                    License(name: "Introspect", author: "Timber Software", filename: "Introspect"),
                ])
            }
            .navigationBarItems(trailing: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
                    .bold()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

}
