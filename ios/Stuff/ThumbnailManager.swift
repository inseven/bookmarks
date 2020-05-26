//
//  ThumbnailManager.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 25/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

//extension UIImage {
//
//    convenience init(path: URL) throws {
//        self.init(data: try Data(contentsOf: path)) ?? throw
//    }
//
//}

class ThumbnailManager {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let path: URL

    init(path: URL) {
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        self.path = path
    }

    func path(for item: Item) -> URL {
        return self.path.appendingPathComponent(item.identifier).appendingPathExtension("png")
    }

    static func image(path: URL) throws -> UIImage {
        guard let image = UIImage.init(data: try Data(contentsOf: path)) else {
            throw StoreError.notFound
        }
        return image
    }

    static func write(image: UIImage, path: URL) {
        do {
            let data = image.pngData()
            try data?.write(to: path, options: .atomic)
            print("Successfully wrote thumbnail to path \(path.absoluteString)")
        } catch {
            print("Failed to write thumbnail to file with error \(error)")
        }
    }

    func thumbnail(for item: Item, completion: @escaping (Result<UIImage, Error>) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {

            let path = self.path(for: item)
            if let image = try? ThumbnailManager.image(path: path) {
                self.targetQueue.async {
                    completion(.success(image))
                }
                return
            }

            downloadThumbnail(for: item.url) { (result) in

                self.targetQueue.async {
                    completion(result)
                }

                if case let .success(image) = result {
                    self.syncQueue.async {
                        ThumbnailManager.write(image: image, path: path)
                    }
                }

            }

        }
    }
}
