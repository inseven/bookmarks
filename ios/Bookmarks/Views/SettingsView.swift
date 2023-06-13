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

    enum SheetType: Identifiable {

        var id: Self {
            return self
        }

        case about
    }

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var applicationModel: ApplicationModel

    @ObservedObject var settings: Settings
    @State var sheet: SheetType?

    var body: some View {
        VStack {
            Form {
                Section("Viewing") {
                    Toggle("Use In-App Browser", isOn: $settings.useInAppBrowser)
                }
                SidebarSettingsSection(settings: settings)
                Section {
                    NavigationLink("Debug") {
                        DebugSettingsView(settings: settings)
                    }
                }
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
                        dismiss()
                        applicationModel.logout { _ in }
                    } label: {
                        Text("Log Out")
                    }
                }
            }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .toolbar {

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .bold()
                }
            }

        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .about:
                AboutView(Legal.contents)
            }
        }
    }
}
