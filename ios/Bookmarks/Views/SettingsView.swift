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

import Diligence

import BookmarksCore

struct SettingsView: View {

    enum SheetType {
        case about
    }

    enum AlertType {
        case error(error: Error)
        case success(message: String)
    }

    @Environment(\.manager) var manager: BookmarksManager
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var settings: Settings
    @State var sheet: SheetType?
    @State var alert: AlertType?

    var body: some View {
        VStack {
            Form {
                Section("Viewing") {
                    Toggle("Use In-App Browser", isOn: $settings.useInAppBrowser)
                }
#if DEBUG
                Section {
                    NavigationLink("Debug") {
                        DebugView(settings: settings)
                    }
                }
#endif
                Section {
                    Button {
                        sheet = .about
                    } label: {
                        Text("About Bookmarks...")
                            .foregroundColor(.primary)
                    }
                }
                Section {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        manager.logout { _ in }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .navigationBarItems(trailing: Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            Text("Done")
                .bold()
        })
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .about:
                AboutView(Legal.contents)
            }
        }
        .alert(item: $alert) { alert in
            switch alert {
            case .error(let error):
                return Alert(title: Text("Error"), message: Text(error.localizedDescription))
            case .success(let message):
                return Alert(title: Text("Success"), message: Text(message))
            }
        }
    }
}

extension SettingsView.SheetType: Identifiable {
    public var id: String {
        switch self {
        case .about:
            return "about"
        }
    }
}

extension SettingsView.AlertType: Identifiable {
    public var id: String {
        switch self {
        case .error:
            return "error"
        case .success:
            return "success"
        }
    }
}
