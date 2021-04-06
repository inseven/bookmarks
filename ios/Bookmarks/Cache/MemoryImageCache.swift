// Copyright (c) 2020-2021 Jason Barrie Morley
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
