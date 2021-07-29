// Copyright (c) 2020-2021 InSeven Limited
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

    var item: Item

    @Environment(\.manager) var manager: BookmarksManager
    @State var image: SafeImage?
    @State var publisher: AnyCancellable?

    public init(item: Item) {
        self.item = item
        _image = State(wrappedValue: manager.cache.object(forKey: item.url.absoluteString as NSString))
    }

    var title: String {
        if !item.title.isEmpty {
            return item.title
        } else if !item.url.lastPathComponent.isEmpty && item.url.lastPathComponent != "/" {
            return item.url.lastPathComponent
        } else if let host = item.url.host {
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
        .aspectRatio(4/3, contentMode: .fit)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            VStack(alignment: .leading) {
                Text(title)
                    .lineLimit(1)
                Text(item.url.host ?? "Unknown")
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.controlSecondaryBackground)
        }
        .background(Color.controlBackground)
        .cornerRadius(10)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            guard image == nil else {
                return
            }
            // TODO: Determine the appropriate default size for thumbnails.
            publisher = manager.thumbnailManager.thumbnail(for: item, scale: 2)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { (completion) in
                    if case .failure(let error) = completion {
                        print("Failed to download thumbnail with error \(error)")
                    }
                }, receiveValue: { image in
                    self.image = image
                    self.manager.cache.setObject(image, forKey: item.url.absoluteString as NSString)
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
