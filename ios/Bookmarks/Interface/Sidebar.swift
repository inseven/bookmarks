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
        case tags
    }

    @Environment(\.manager) var manager: BookmarksManager
    @EnvironmentObject var settings: Settings

    @ObservedObject var sceneModel: SceneModel
    
    @State var sheet: Sheet?
    
    var body: some View {
        List(selection: $sceneModel.section) {
            Section("Smart Filters") {
                SectionLink(.all)
                SectionLink(.shared(false))
                SectionLink(.shared(true))
                SectionLink(.today)
                SectionLink(.unread)
                SectionLink(.untagged)
            }

            if settings.favoriteTags.count > 0 {

                Section("Favorites") {
                    ForEach(settings.favoriteTags.sorted(), id: \.section) { tag in
                        SectionLink(tag.section)
                            .contextMenu {
                                Button(role: .destructive) {
                                    settings.favoriteTags = settings.favoriteTags.filter { $0 != tag }
                                } label: {
                                    Label("Remove from Favorites", systemImage: "star.slash")
                                }
                            }
                    }
                }

            }

        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView(settings: manager.settings)
                }
            case .tags:
                TagsEditorView()
            }
        }
        .navigationTitle("Filters")
        .toolbar {

            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    sheet = .settings
                } label: {
                    Image(systemName: "gear")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    sheet = .tags
                } label: {
                    Image(systemName: "tag")
                }
            }

        }
    }
    
}
