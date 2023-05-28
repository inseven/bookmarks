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

import Combine
import SwiftUI

import BookmarksCore
import Interact

struct Sidebar: View {

    enum SheetType {
        case rename(tag: String)
    }

    @ObservedObject var manager: BookmarksManager
    @StateObject var tagsView: TagsView
    @ObservedObject var settings: BookmarksCore.Settings
    @ObservedObject var windowModel: WindowModel

    @State var sheet: SheetType? = nil

    var tags: [String] {
        tagsView.tags.filter { !settings.favoriteTags.contains($0) }
    }

    var body: some View {
        List(selection: $windowModel.section) {
            Section {
                ForEach(BookmarksSection.defaultSections) { section in
                    SectionLink(section)
                }
            }

            if settings.favoriteTags.count > 0 {

                Section("Favorites") {
                    ForEach(settings.favoriteTags.sorted(), id: \.section) { tag in
                        SectionLink(tag.section)
                            .contextMenu(ContextMenu(menuItems: {
                                Button("Remove from Favorites") {
                                    settings.favoriteTags = settings.favoriteTags.filter { $0 != tag }
                                }
                                Divider()
                                Button("Edit on Pinboard") {
                                    do {
                                        guard let user = manager.user else {
                                            return
                                        }
                                        NSWorkspace.shared.open(try tag.pinboardTagUrl(for: user))
                                    } catch {
                                        print("Failed to open on Pinboard error \(error)")
                                    }
                                }
                            }))
                    }
                }
            }

        }
        .safeAreaInset(edge: .bottom) {

            if manager.isUpdating {
                VStack(spacing: 0) {
                    Divider()
                    Text("Updating...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }

        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .rename(let tag):
                RenameTagView(tag: tag)
            }
        }
    }
}

extension Sidebar.SheetType: Identifiable {

    var id: String {
        switch self {
        case .rename(let tag):
            return "rename:\(tag)"
        }
    }

}
