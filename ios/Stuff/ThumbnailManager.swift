//
//  ThumbnailManager.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 25/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit
import Combine


class ThumbnailManager {

    let targetQueue: DispatchQueue
    let imageCache: ImageCache
    let downloadManager: DownloadManager

    init(imageCache: ImageCache, downloadManager: DownloadManager) {
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        self.imageCache = imageCache
        self.downloadManager = downloadManager
    }

    func cachedImage(for item: Item) -> Future<UIImage, Error> {
        return Future { (promise) in
            self.imageCache.get(identifier: item.identifier) { (result) in
                promise(result)
            }
        }
    }

    func thumbnail(for item: Item) -> AnyPublisher<UIImage, Error> {
        return cachedImage(for: item)
            .catch{ _ in Utilities.meta(for: item.url) }
            .catch{ _ in self.downloadManager.thumbnail(for: item.url) }
            .map({ (image) -> UIImage in
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
