//
//  MemoryImageCache.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class MemoryImageCache: ImageCache {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    var cache = NSCache<NSString, UIImage>()

    init(targetQueue: DispatchQueue? = nil) {
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = targetQueue ?? DispatchQueue(label: "targetQueue")
    }

    func set(identifier: String, image: UIImage, completion: @escaping (Result<Bool, Error>) -> Void) {
        let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
        syncQueue.async {
            self.cache.setObject(image, forKey: identifier as NSString)
            targetQueueCompletion(.success(true))
        }
    }

    func get(identifier: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
        syncQueue.async {
            guard let image = self.cache.object(forKey: identifier as NSString) else {
                targetQueueCompletion(.failure(ImageCacheError.notFound))
                return
            }
            targetQueueCompletion(.success(image))
        }
    }

    func clear(completion: @escaping (Result<Bool, Error>) -> Void) {
        syncQueue.async {
            let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
            self.cache.removeAllObjects()
            targetQueueCompletion(.success(true))
        }
    }

}
