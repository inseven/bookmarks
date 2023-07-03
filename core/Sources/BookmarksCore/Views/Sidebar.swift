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

public struct Sidebar: View {

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var settings: Settings

    @Binding var sceneState: SceneState

    public var body: some View {
        SidebarContentView(sceneState: $sceneState)
#if os(iOS)
            .refreshable {
                await applicationModel.refresh()
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            sceneState.showSettings()
                        } label: {
                            Image(systemName: "gear")
                        }
                        Spacer()
                        StatusView()
                        Spacer()
                        Button {
                            sceneState.showTags()
                        } label: {
                            Image(systemName: "tag")
                        }
                    }
                }
            }
#endif
#if os(macOS)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    StatusView()
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
#endif
    }

}
