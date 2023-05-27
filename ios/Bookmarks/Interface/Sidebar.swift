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

import BookmarksCore

struct Sidebar: View {

    enum Sheet: Identifiable {

        var id: Self { self }

        case settings
    }

    @Environment(\.manager) var manager: BookmarksManager
    @State var section: BookmarksSection? = .all
    @State var sheet: Sheet?
    
    var body: some View {
        List {
            Section("Smart Filters") {
                SidebarLink(selection: $section, section: .all)
                SidebarLink(selection: $section, section: .shared(false))
                SidebarLink(selection: $section, section: .shared(true))
                SidebarLink(selection: $section, section: .today)
                SidebarLink(selection: $section, section: .unread)
                SidebarLink(selection: $section, section: .untagged)
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView(settings: manager.settings)
                }
            }
        }
        .navigationTitle("Filters")
        .navigationBarItems(leading: Button {
            sheet = .settings
        } label: {
            Image(systemName: "gear")
        })
    }
    
}
