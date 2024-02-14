// Copyright (c) 2020-2024 Jason Morley
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

    struct LayoutMetrics {
        static let indicatorSize = 16.0
    }

    @EnvironmentObject var settings: Settings

    @StateObject var model: TagsContentViewModel

    public init(applicationModel: ApplicationModel) {
        _model = StateObject(wrappedValue: TagsContentViewModel(applicationModel: applicationModel))
    }

    public var body: some View {
        Table(of: Database.Tag.self, selection: $model.selection) {
            TableColumn("") { tag in
                Image(systemName: "circle.fill")
                    .foregroundColor(tag.name.color())
            }
            .width(LayoutMetrics.indicatorSize)
            TableColumn("Tag") { tag in
                Text(tag.name)
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
            model.open(tags: .items(selection))
        }
        .onDeleteCommand {
            model.delete(tags: .selection)
        }
        .searchable(text: $model.filter)
        .toggleStyle(.favorite)
        .presents($model.confirmation)
        .presents($model.error)
        .runs(model)
    }

}
