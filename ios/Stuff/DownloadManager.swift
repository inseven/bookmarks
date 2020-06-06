//
//  DownloadManager.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 06/06/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class DownloadManager {

    let syncQueue: DispatchQueue
    let limit: Int
    var pending: [AnyHashable]
    var active: Set<AnyHashable>

    init(limit: Int) {
        syncQueue = DispatchQueue(label: "syncQueue")
        self.limit = limit
        pending = []
        active = Set()
    }

    private func debug() {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let urls = self.active.map { (item) -> String in
            let downloader = item as! WebViewDownloader
            return downloader.description
        }

        print("DownloadManager (limit=\(self.limit): \(self.pending.count) pending, \(self.active.count) active \(urls)")
    }

    private func add<T>(_ downloader: T) where T: Hashable {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            self.pending.append(downloader)
            self.run()
        }
    }

    private func remove<T>(_ downloader: T) where T: Hashable {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            if let index = self.pending.firstIndex(of: downloader) {
                self.pending.remove(at: index)
            }
            self.active.remove(downloader)
            self.run()
        }
    }

    private func run() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        defer { self.debug() }
        guard
            self.active.count < limit,
            !self.pending.isEmpty,
            let next = self.pending.removeLast() as? WebViewDownloader else {
                return
        }
        _ = self.active.insert(next)
        next.start()
    }

    func downloader(for url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) -> Downloader {
        let userInteractiveCompletion = Utilities.completion(on: .global(qos: .userInteractive), completion: completion)
        var downloader: WebViewDownloader?
        downloader = WebViewDownloader(url: url) { (result) in
            defer { self.remove(downloader!) }
            switch result {
            case .success(let imageUrl):
                DispatchQueue.global(qos: .background).async {
                    guard let image = UIImage.init(contentsOf: imageUrl) else {
                        userInteractiveCompletion(.failure(OpenGraphError.invalidArgument(message: "Unable to fetch image")))
                        return
                    }
                    userInteractiveCompletion(.success(image))
                }
            case .failure(let error):
                userInteractiveCompletion(.failure(error))
            }
        }
        return downloader!
    }

    func schedule<T>(_ downloader: T) where T: Hashable {
        self.add(downloader)
    }

    func thumbnail(for url: URL) -> WebViewThumbnailPublisher {
        return WebViewThumbnailPublisher(manager: self, url: url)
    }

}
