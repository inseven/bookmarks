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

import Foundation
import Combine

#if os(iOS)
import UIKit
#endif

public class ThumbnailManager {

    let targetQueue: DispatchQueue
    let imageCache: ImageCache
    let downloadManager: DownloadManager

    public init(imageCache: ImageCache, downloadManager: DownloadManager) {
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        self.imageCache = imageCache
        self.downloadManager = downloadManager
    }

    func cachedImage(for bookmark: Bookmark) -> Future<SafeImage, Error> {
        return Future { (promise) in
            self.imageCache.get(identifier: bookmark.identifier) { (result) in
                promise(result)
            }
        }
    }

    func fetchImage(for bookmark: Bookmark, scale: CGFloat) -> AnyPublisher<SafeImage, Error> {
        return Utilities.meta(for: bookmark.url)
            .catch { _ in self.downloadManager.thumbnail(for: bookmark.url) }
            .flatMap { $0.resize(height: 200 * scale) }
            .eraseToAnyPublisher()
    }

    public func thumbnail(for bookmark: Bookmark, scale: CGFloat) -> AnyPublisher<SafeImage, Error> {
        return cachedImage(for: bookmark)
            .catch { _ in self.fetchImage(for: bookmark, scale: scale)
                .map { (image) -> SafeImage in
                    self.imageCache.set(identifier: bookmark.identifier, image: image) { (result) in
                        if case .failure(let error) = result {
                            print("Failed to cache image with error \(error)")
                        }
                    }
                    return image
                }
            }
            .eraseToAnyPublisher()
    }

}
