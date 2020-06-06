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

    init(imageCache: ImageCache) {
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        self.imageCache = imageCache
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
            .catch{ _ in WebViewThumbnailPublisher(url: item.url) }
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

//    func thumbnail(for item: Item, completion: @escaping (Result<UIImage, Error>) -> Void) -> Downloader? {
//        let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
//        let downloader = DownloadManager.shared.downloader(for: item.url) { (result) in
//            defer { targetQueueCompletion(result) }
//            guard case let .success(image) = result else {
//                return
//            }
//            self.imageCache.set(identifier: item.identifier, image: image) { (result) in
//                if case .failure(let error) = result {
//                    print("Failed to cache image with error \(error)")
//                }
//            }
//        }
//        self.imageCache.get(identifier: item.identifier) { (result) in
//            if case .success(let image) = result {
//                targetQueueCompletion(.success(image))
//                return
//            }
//            DownloadManager.shared.schedule(downloader as! WebViewDownloader)
//        }
//        return downloader
//    }
}
