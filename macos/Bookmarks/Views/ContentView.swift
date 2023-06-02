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

import BookmarksCore

struct ContentView: View {

    @FocusedObject var sectionViewModel: SectionViewModel?

    @ObservedObject var applicationModel: ApplicationModel

    @StateObject var sceneModel: SceneModel
    @State var sheet: ApplicationState? = nil

    init(applicationModel: ApplicationModel) {
        self.applicationModel = applicationModel
        _sceneModel = StateObject(wrappedValue: SceneModel(settings: applicationModel.settings))
    }

    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            if let section = sceneModel.section {
                SectionView(applicationModel: applicationModel, section: section)
                    .id(section)
                    .environmentObject(sceneModel)
            } else {
                PlaceholderView("Nothing Selected")
                    .searchable()
            }
        }
        .toolbar(id: "main") {
            AccountToolbar()
            LayoutToolbar()
            SelectionToolbar(sectionViewModel: sectionViewModel ?? SectionViewModel())
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .logIn:
                LogInView()
            }
        }
        .onChange(of: applicationModel.state) { newValue in
            switch newValue {
            case .idle:
                sheet = nil
            case .unauthorized:
                sheet = .logIn
            }
        }
        .environmentObject(sceneModel)
        .focusedSceneObject(sceneModel)
    }

}
