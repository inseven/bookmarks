//
//  ImageDownloader.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

class ImageDownloader {

    enum State {
        case idle
        case initializing
    }

    let syncQueue: DispatchQueue
    let store: Store
    var state: State // Synchronized on syncQueue

    init(store: Store) {
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.store = store
        self.state = .idle
    }

    private func thumbnail(for url: URL) throws -> UIImage {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<UIImage, Error> = .failure(StoreError.notFound)
        downloadThumbnail(for: url) { (completionResult) in
            result = completionResult
            semaphore.signal()
        }
        semaphore.wait()
        switch result {
        case .failure(let error):
            throw error
        case .success(let item):
            return item
        }
    }

    private func item(identifier: String) throws -> Item {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Item, StoreError> = .failure(.notFound)
        self.store.item(identifier: identifier) { (completionResult) in
            result = completionResult
            semaphore.signal()
        }
        semaphore.wait()
        switch result {
        case .failure(let error):
            throw error
        case .success(let item):
            return item
        }
    }

    private func identifiers() throws -> [String] {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String], StoreError> = .failure(.notFound)
        self.store.identifiers { (completionResult) in
            result = completionResult
            semaphore.signal()
        }
        semaphore.wait()
        switch result {
        case .failure(let error):
            throw error
        case .success(let identifiers):
            return identifiers
        }
    }

    private func update() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        do {
            for identifier in try self.identifiers() {
                let item = try self.item(identifier: identifier)
                print("Processing '\(item.title)'...")
                guard item.thumbnail == nil else {
                    continue
                }
                guard let thumbnail = try? self.thumbnail(for: item.url) else {
                    continue
                }
                store.save(items: [Item(identifier: item.identifier,
                                        title: item.title,
                                        url: item.url,
                                        tags: item.tags,
                                        date: item.date,
                                        thumbnail: thumbnail)]) { (success) in
                    print("Updated item!")
                }
            }
        } catch {
            print("Failed to get identifiers with error \(error)")
            return
        }
    }

    func start() {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            guard self.state == .idle else {
                return
            }
            self.state = .initializing
            self.store.add(observer: self)
            self.update()
        }
    }

}

extension ImageDownloader : StoreObserver {

    func storeDidUpdate(store: Store) {
        syncQueue.async {
            self.update()
        }
    }

}
