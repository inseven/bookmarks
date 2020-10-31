//
//  Store.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

enum StoreError: Error {
    case notFound
}

protocol StoreObserver {
    func storeDidUpdate(store: Store)
}

extension String {

    func like(_ search: String) -> Bool {
        guard !search.isEmpty else {
            return true
        }
        return self.lowercased().contains(search.lowercased())
    }

}

class Store {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let path: URL
    var items: [String: Item] // Synchronized on syncQueue
    var observers: [StoreObserver] // Synchronized on syncQueue
    var rawItems: [Item] = [] // Synchronized on the main thread.

    init(path: URL, targetQueue: DispatchQueue?) {
        syncQueue = DispatchQueue(label: "syncQueue")
        if let targetQueue = targetQueue {
            self.targetQueue = targetQueue
        } else {
            self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        }
        self.path = path
        items = [:]
        observers = []
    }

    func add(observer: StoreObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.append(observer)
        }
    }

    func thumbnailPath(item: Item) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(item.identifier).appendingPathExtension("png")
    }

    func identifiers(filter: String? = nil, completion: @escaping (Result<[String], StoreError>) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            let items = self.items.values.filter { (item) -> Bool in
                guard let filter = filter else {
                    return true
                }

                let filters = filter.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
                var fields = Array(item.tags)
                fields.append(contentsOf: [item.title, item.url.absoluteString])
                return filters.reduce(true) { (result, filter) -> Bool in
                    return result && fields.reduce(false) { (result, field) -> Bool in
                        return result || field.like(filter)
                    }
                }

            }

            let identifiers = items.sorted { (lhs, rhs) -> Bool in
                return lhs.date > rhs.date
            }.map { $0.identifier }
            self.targetQueue.async {
                completion(.success(identifiers));
            }
        }
    }

    func item(identifier: String, completion: @escaping (Result<Item, StoreError>) -> Void) {
        syncQueue.async {
            let item = self.items[identifier]
            self.targetQueue.async {
                guard let item = item else {
                    completion(.failure(.notFound))
                    return
                }
                completion(.success(item))
            }
        }
    }

    private func write() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
    }

    func save(items: [Item], completion: @escaping (Bool) -> Void) {
        syncQueue.async {
            for item in items {
                self.items[item.identifier] = item
            }
            self.write()
            let observers = self.observers
            self.targetQueue.async {
                completion(true)
                for observer in observers {
                    observer.storeDidUpdate(store: self)
                }
            }
        }
        DispatchQueue.main.async {
            self.rawItems = items
        }
    }

}
