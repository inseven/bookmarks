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

#if os(iOS)
import UIKit
#endif

public class FileImageCache: ImageCache {

    let path: URL
    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue

    public init(path: URL, targetQueue: DispatchQueue? = nil) {
        self.path = path
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = targetQueue ?? DispatchQueue(label: "targetQueue")
        try! FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    }

    func path(for identifier: String) -> URL {
        return self.path.appendingPathComponent(identifier).appendingPathExtension("png")
    }

    public func set(identifier: String, image: SafeImage, completion: @escaping (Result<Bool, Error>) -> Void) {
        let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
        syncQueue.async {
            do {
                let path = self.path(for: identifier)
                let data = image.pngData()
                try data?.write(to: path, options: .atomic)
                targetQueueCompletion(.success(true))
            } catch {
                targetQueueCompletion(.failure(error))
            }
        }
    }

    public func get(identifier: String, completion: @escaping (Result<SafeImage, Error>) -> Void) {
        let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
        syncQueue.async {
            let path = self.path(for: identifier)
            do {
                let data = try Data(contentsOf: path)
                guard let image = SafeImage.init(data: data) else {
                    targetQueueCompletion(.failure(BookmarksError.corrupt))
                    return
                }
                targetQueueCompletion(.success(image))
            } catch {
                targetQueueCompletion(.failure(error))
            }
        }
    }

    public func clear(completion: @escaping (Result<Bool, Error>) -> Void) {
        let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
        syncQueue.async {
            do {
                try FileManager.default.removeItem(at: self.path)
                try! FileManager.default.createDirectory(at: self.path, withIntermediateDirectories: true)
                targetQueueCompletion(.success(true))
            } catch {
                targetQueueCompletion(.failure(error))
            }
        }
    }

}
