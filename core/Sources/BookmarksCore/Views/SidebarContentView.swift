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

public struct SidebarContentView: View {

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var settings: Settings

    @Binding var sceneState: SceneState

    public var body: some View {
        List(selection: $sceneState.section) {
            if case let .tag(tag) = sceneState .section,
               !settings.favoriteTags.contains(tag),
               !applicationModel.topTags.contains(tag)  {
                Section("Search") {
                    SectionLink(section: .tag(tag))
#if os(macOS)
                        .contextMenu {
                            SidebarTagCommands(tag: tag)
                        }
#else
                        .swipeActions(edge: .trailing) {
                            Button {
                                withAnimation {
                                    applicationModel.addFavorite(tag)
                                }
                            } label: {
                                Label("Add to Favorites", systemImage: "star")
                            }
                            .tint(.accentColor)
                        }
#endif
                }
            }
            Section("Library") {
                ForEach(settings.librarySections) { librarySection in
                    SectionLink(section: librarySection.section)
                }
            }
            if !settings.favoriteTags.isEmpty {
                Section("Favorites") {
                    ForEach(settings.favoriteTags.sorted(), id: \.section) { tag in
                        SectionLink(section: .tag(tag))
#if os(macOS)
                            .contextMenu {
                                SidebarTagCommands(tag: tag)
                            }
#else
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        applicationModel.removeFavorite(tag)
                                    }
                                } label: {
                                    Label("Remove from Favorites", systemImage: "star.slash")
                                }
                            }
#endif
                    }
                }
            }
            if !applicationModel.topTags.isEmpty {
                Section("Top Tags") {
                    ForEach(applicationModel.topTags, id: \.section) { tag in
                        SectionLink(section: .tag(tag))
#if os(macOS)
                            .contextMenu {
                                SidebarTagCommands(tag: tag)
                            }
#else
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation {
                                        applicationModel.addFavorite(tag)
                                    }
                                } label: {
                                    Label("Add to Favorites", systemImage: "star")
                                }
                                .tint(.accentColor)
                            }
#endif
                    }
                }
            }
        }
    }

}
