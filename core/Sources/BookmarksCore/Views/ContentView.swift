// Copyright (c) 2020-2024 InSeven Limited
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

import Interact

public struct ContentView: View {

    @Environment(\.openWindow) var openWindow

    @ObservedObject var applicationModel: ApplicationModel

    @MainActor @SceneStorage("sceneState") var sceneState = SceneState()

    @State var sheet: ApplicationState? = nil

    public init(applicationModel: ApplicationModel) {
        self.applicationModel = applicationModel
    }

    public var body: some View {
        NavigationSplitView {
            Sidebar(sceneState: $sceneState)
        } detail: {
            if let section = sceneState.section {
                SectionView(applicationModel: applicationModel,
                            sceneState: $sceneState,
                            section: section,
                            openWindow: openWindow)
                    .id(section)
            } else {
                PlaceholderView("Nothing Selected")
                    .searchable()
            }
        }
#if os(macOS)
        .toolbar(id: "main") {
            AccountToolbar()
            ApplicationToolbar()
            LayoutToolbar()
            SelectionToolbar()
        }
#endif
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .logIn:
                LogInView()
            }
        }
#if os(iOS)
        .sheet(item: $sceneState.sheet) { sheet in
            switch sheet {
            case .tags:
                PhoneTagsView(applicationModel: applicationModel)
            case .settings:
                PhoneSettingsView(settings: applicationModel.settings)
            case .edit(let id):
                PhoneInfoView(id: id)
            }
        }
        .fullScreenCover(item: $sceneState.previewURL) { url in
            PhoneSafariView(url: url)
                .edgesIgnoringSafeArea(.all)
        }
#endif
        .onChange(of: applicationModel.state) { newValue in
            switch newValue {
            case .idle:
                sheet = nil
            case .unauthorized:
                sheet = .logIn
            }
        }
        .handlesSceneActions($sceneState)
        .focusedSceneValue(\.sceneState, $sceneState)
    }

}
