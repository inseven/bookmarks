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

    func cachedImage(for item: Item) -> Future<Image, Error> {
        return Future { (promise) in
            self.imageCache.get(identifier: item.identifier) { (result) in
                promise(result)
            }
        }
    }

    public func thumbnail(for item: Item, scale: CGFloat) -> AnyPublisher<Image, Error> {
        return cachedImage(for: item)
            .catch { _ in Utilities.meta(for: item.url).flatMap { $0.resize(height: 200 * scale) } }
            .catch { _ in self.downloadManager.thumbnail(for: item.url).flatMap { $0.resize(height: 200 * scale) } }
            .map({ (image) -> Image in
                self.imageCache.set(identifier: item.identifier, image: image) { (result) in
                    if case .failure(let error) = result {
                        print("Failed to cache image with error \(error)")
                    }
                }
                return image
            })
            .eraseToAnyPublisher()
    }

}
