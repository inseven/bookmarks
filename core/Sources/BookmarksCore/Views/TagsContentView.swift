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

import Interact

public struct TagsContentView: View {

    @Environment(\.openURL) var openURL

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var settings: Settings

    @StateObject var model: TagsContentViewModel

    public init(tagsModel: TagsModel) {
        _model = StateObject(wrappedValue: TagsContentViewModel(tagsModel: tagsModel))
    }

    public var body: some View {
        Table(model.filteredTags, selection: $model.selection) {
            TableColumn("Tag") { tag in
                TagView(tag.name, color: tag.name.color())
            }
            TableColumn("Count") { tag in
                Text(String(describing: tag.count))
            }
            TableColumn("Favorite") { tag in
                Toggle(isOn: $settings.favoriteTags.contains(tag.name))
            }
        }
        .contextMenu(forSelectionType: String.ID.self) { selection in

        } primaryAction: { selection in
            guard selection.count == 1,
                  let tag = selection.first,
                  let actionURL = URL(forOpeningTag: tag) else {
                return
            }
            print(actionURL.absoluteString)
            openURL(actionURL)
        }
        .searchable(text: $model.filter)
        .runs(model)
    }

}
