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

struct BookmarksView: View {

    enum SheetType {
        case settings
    }

    @Environment(\.manager) var manager: BookmarksManager
    @StateObject var databaseView: ItemsView

    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))
    @State var sheet: SheetType?

    var body: some View {
        VStack {
            HStack {
                TextField("Search", text: $searchDebouncer.value)
                    .autocapitalization(.none)
                    .modifier(SearchBoxModifier(text: $searchDebouncer.value))
                    .padding()
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(databaseView.items) { item in
                        BookmarkCell(item: item)
                            .onTapGesture {
                                UIApplication.shared.open(item.url)
                            }
                            .contextMenu(ContextMenu(menuItems: {
                                Button("Share") {
                                    print("Share")
                                    print(item.identifier)
                                }
                            }))
                    }
                }
                .padding()
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
        .navigationBarItems(leading: Button("Settings") {
            sheet = .settings
        })
        .onAppear {
            databaseView.start()
        }
        .onDisappear {
            databaseView.stop()
        }
        .onReceive(searchDebouncer.$debouncedValue) { value in
            databaseView.query = AnyQuery.parse(filter: value)
        }
    }

}

extension BookmarksView.SheetType: Identifiable {
    public var id: Self { self }
}
