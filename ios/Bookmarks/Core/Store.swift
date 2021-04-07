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
import SwiftUI
import UIKit

import BookmarksCore

enum StoreError: Error {
    case notFound
}

protocol StoreObserver {
    func storeDidUpdate(store: Store)
}

class Store: ObservableObject {

    static let itemsKey = "items"

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let path: URL
    var items: [String: Item] // Synchronized on syncQueue
    var observers: [StoreObserver] // Synchronized on syncQueue
    var tags: [String] = []

    @Published var rawItems: [Item] = [] {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            let encodedItems: Data = try! NSKeyedArchiver.archivedData(withRootObject: rawItems, requiringSecureCoding: true)
            UserDefaults.standard.set(encodedItems, forKey: Store.itemsKey)
            UserDefaults.standard.synchronize()
            tags = Array(Set(rawItems.map { Set($0.tags) }.reduce([], +))).sorted { $0.localizedCompare($1) == .orderedAscending }
            self.objectWillChange.send()
        }
    }

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
        if let encodedItems = UserDefaults.standard.object(forKey: Store.itemsKey) as? Data,
           let rawItems = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: Item.self, from: encodedItems) {
            self.rawItems = rawItems
        }
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
