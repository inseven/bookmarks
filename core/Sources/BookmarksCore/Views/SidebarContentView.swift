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

import Interact

public struct SidebarContentView: View {

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var sceneModel: SceneModel
    @EnvironmentObject var settings: Settings

    public init() {

    }

    public var body: some View {
        List(selection: $sceneModel.section) {
            Section("Smart Filters") {
                ForEach(BookmarksSection.defaultSections) { section in
                    SectionLink(section)
                }
            }
            if settings.favoriteTags.count > 0 {
                Section("Favorite Tags") {
                    ForEach(settings.favoriteTags.sorted(), id: \.section) { tag in
                        SectionLink(tag.section, color: tag.color())
                            .contextMenu {
                                Button {
                                    do {
                                        guard let user = applicationModel.user else {
                                            return
                                        }
                                        Application.open(try tag.pinboardTagUrl(for: user))
                                    } catch {
                                        print("Failed to open on Pinboard error \(error)")
                                    }
                                } label: {
                                    Label("View on Pinboard", systemImage: "pin")

                                }
                                Divider()
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
    }

}
