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

import BookmarksCore

struct BookmarkCell: View {

    var item: Item

    @Environment(\.manager) var manager: BookmarksManager
    @State var image: UIImage?
    @State var publisher: AnyCancellable?

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
            Text(title)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .clipped()
                    .background(Color.white)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            thumbnail
                .frame(height: 100)
                .clipped()
            VStack(alignment: .leading) {
                Text(title)
                    .lineLimit(1)
                Text(item.url.host ?? "Unknown")
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .onAppear {
            publisher = manager.thumbnailManager.thumbnail(for: item, scale: UIScreen.main.scale)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { (completion) in
                    if case .failure(let error) = completion {
                        print("Failed to download thumbnail with error \(error)")
                    }
                }, receiveValue: { image in
                    self.image = image
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
