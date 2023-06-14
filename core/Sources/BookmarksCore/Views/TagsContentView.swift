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

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif

    @Environment(\.openURL) var openURL

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var settings: Settings

    @StateObject var model: TagsContentViewModel

    public init(applicationModel: ApplicationModel) {
        _model = StateObject(wrappedValue: TagsContentViewModel(applicationModel: applicationModel))
    }

    public var body: some View {
        Table(of: Database.Tag.self, selection: $model.selection) {
            TableColumn("Tag") { tag in
                if isCompact {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(tag.name.color())
                        Text(tag.name)
                        Spacer()
                        Text(tag.count.formatted())
                        Toggle("Favorite", isOn: $settings.favoriteTags.contains(tag.name))
                            .toggleStyle(.favorite)
                    }

                } else {
                    TagView(tag.name, color: tag.name.color())
                }
            }
            TableColumn("Count") { tag in
                Text(String(describing: tag.count))
            }
            TableColumn("Favorite") { tag in
                Toggle(isOn: $settings.favoriteTags.contains(tag.name))
            }
        } rows: {
            ForEach(model.filteredTags) { tag in
                TableRow(tag)
            }
        }
        .contextMenu(forSelectionType: String.ID.self) { selection in
            Button(role: .destructive) {
                model.delete(tags: .items(selection))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } primaryAction: { selection in
            guard selection.count == 1,
                  let tag = selection.first,
                  let actionURL = URL(forOpeningTag: tag) else {
                return
            }
            print(actionURL.absoluteString)
            openURL(actionURL)
        }
        .onDeleteCommand {
            model.delete(tags: .selection)
        }
        .searchable(text: $model.filter)
        .presents($model.confirmation)
        .presents($model.error)
        .runs(model)
    }

}
