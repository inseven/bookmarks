//
//  FileImageCache.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class FileImageCache: ImageCache {

    let path: URL
    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue

    init(path: URL, targetQueue: DispatchQueue? = nil) {
        self.path = path
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = targetQueue ?? DispatchQueue(label: "targetQueue")
        try! FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    }

    func path(for identifier: String) -> URL {
        return self.path.appendingPathComponent(identifier).appendingPathExtension("png")
    }

    func set(identifier: String, image: UIImage, completion: @escaping (Result<Bool, Error>) -> Void) {
        syncQueue.async {
            let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
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

    func get(identifier: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        syncQueue.async {
            let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
            let path = self.path(for: identifier)
            do {
                let data = try Data(contentsOf: path)
                guard let image = UIImage.init(data: data) else {
                    targetQueueCompletion(.failure(StoreError.notFound))
                    return
                }
                targetQueueCompletion(.success(image))
            } catch {
                targetQueueCompletion(.failure(error))
            }
        }
    }

    func clear(completion: @escaping (Result<Bool, Error>) -> Void) {
        syncQueue.async {
            let targetQueueCompletion = Utilities.completion(on: self.targetQueue, completion: completion)
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
