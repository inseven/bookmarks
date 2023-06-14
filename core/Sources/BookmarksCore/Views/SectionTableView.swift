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

public struct SectionTableView: View {

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif

    @Environment(\.openWindow) var openWindow

    @EnvironmentObject var sectionViewModel: SectionViewModel

    public init() {

    }

    public var body: some View {
        Table(sectionViewModel.bookmarks, selection: $sectionViewModel.selection) {
            TableColumn("") { bookmark in
                if isCompact {
                    HStack(spacing: 16.0) {
                        VStack {
                            FaviconImage(url: bookmark.url)
                            if bookmark.toRead {
                                UnreadMark(isOn: true)
                            }
                        }
                        VStack(alignment: .leading) {
                            HStack {
                                Text(bookmark.title)
                                Spacer()
                                Text(bookmark.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                            }
                            Text(bookmark.url.absoluteString)
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                    }
                } else {
                    UnreadMark(isOn: bookmark.toRead)
                }

            }
            .width(isCompact ? .none : UnreadMark.LayoutMetrics.size)
            TableColumn("") { bookmark in
                FaviconImage(url: bookmark.url)
            }
            .width(FaviconImage.LayoutMetrics.size.width)
            TableColumn("Title", value: \.title)
            TableColumn("URL", value: \.url.absoluteString)
            TableColumn("Date") { bookmark in
                Text(bookmark.date.formatted(date: .long, time: .standard))
            }
            TableColumn("Tags") { bookmark in
                Text(bookmark.tags.sorted().joined(separator: " "))
            }
        }
        .contextMenu(forSelectionType: Bookmark.ID.self) { selection in
            sectionViewModel.contextMenu(selection, openWindow: openWindow)
        } primaryAction: { selection in
            sectionViewModel.open(ids: selection)
        }
    }

}
