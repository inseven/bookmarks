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

public struct BookmarkCell: View {

    private struct LayoutMetrics {
        static let cornerRadius = 10.0
        static let horizontalSpacing = 8.0
    }

    var bookmark: Bookmark
    let applicationModel: ApplicationModel

    @State var image: SafeImage?
    @State var publisher: AnyCancellable?

    public init(applicationModel: ApplicationModel, bookmark: Bookmark) {
        self.applicationModel = applicationModel
        self.bookmark = bookmark
        _image = State(wrappedValue: applicationModel.cache.object(forKey: bookmark.url.absoluteString as NSString))
    }

    var title: String {
        if !bookmark.title.isEmpty {
            return bookmark.title
        } else if !bookmark.url.lastPathComponent.isEmpty && bookmark.url.lastPathComponent != "/" {
            return bookmark.url.lastPathComponent
        } else if let host = bookmark.url.host {
            return host
        } else {
            return "Unknown"
        }
    }

    var thumbnail: some View {
        ZStack {
            SwiftUI.Image(systemName: "safari.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.tertiaryLabel)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
            if let image = image {
                SwiftUI.Image(safeImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: image.size.width, maxHeight: image.size.height)
                    .background(Color.white)
                    .layoutPriority(-1)
            }
        }
        .clipped()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            VStack {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(bookmark.url.formatted(.short))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            .lineLimit(1)
            .padding()
            .background(Color.controlSecondaryBackground)
        }
        .background(Color.controlBackground)
        .cornerRadius(LayoutMetrics.cornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadius, style: .continuous))
#if os(iOS)
        .contentShape([.contextMenuPreview],
                      RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadius, style: .continuous))
#endif
        .onAppear {
            guard image == nil else {
                return
            }
            // TODO: Determine the appropriate default size for thumbnails.
            publisher = applicationModel.thumbnailManager.thumbnail(for: bookmark, scale: 2)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { (completion) in
                    if case .failure(let error) = completion {
                        print("Failed to download thumbnail with error \(error)")
                    }
                }, receiveValue: { image in
                    self.image = image
                    self.applicationModel.cache.setObject(image, forKey: bookmark.url.absoluteString as NSString)
                })
        }
        .onDisappear {
            guard let publisher = publisher else {
                return
            }
            publisher.cancel()
        }
    }

}
