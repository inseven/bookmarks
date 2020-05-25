//
//  Store.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

@objc class Item: NSObject, NSSecureCoding {

    let identifier: String
    let title: String
    let url: URL
    let thumbnail: UIImage?

    init(identifier: String, title: String, url: URL, thumbnail: UIImage? = nil) {
        self.identifier = identifier
        self.title = title
        self.url = url
        self.thumbnail = thumbnail
    }

    static var supportsSecureCoding: Bool = true
    static var IdentifierKey = "Identifier"
    static var TitleKey = "Title"
    static var URLKey = "URL"

    func encode(with coder: NSCoder) {
        coder.encode(self.identifier, forKey: Item.IdentifierKey)
        coder.encode(self.title, forKey: Item.TitleKey)
        coder.encode(self.url, forKey: Item.URLKey)
    }

    required init?(coder: NSCoder) {
        guard let identifier = coder.decodeObject(of: NSString.self, forKey: Item.IdentifierKey) else {
            return nil
        }
        guard let title = coder.decodeObject(of: NSString.self, forKey: Item.TitleKey) else {
            return nil
        }
        guard let url = coder.decodeObject(of: NSURL.self, forKey: Item.URLKey) else {
            return nil
        }
        self.identifier = identifier as String
        self.title = title as String
        self.url = url as URL
        self.thumbnail = nil
    }

}

enum StoreError: Error {
    case notFound
}

protocol StoreObserver {

    func storeDidUpdate(store: Store)

}

class Store {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let path: URL
    var items: [String: Item] // Synchronized on syncQueue
    var observers: [StoreObserver] // Synchronized on syncQueue

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

        do {
            let data = try NSData.init(contentsOfFile: self.path.absoluteString) as Data
            let contents = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSString.self, NSDictionary.self, Item.self], from: data)
            print("CONTENTS = \(contents)")
        } catch {
            print("Failed to load file with error \(error)")
        }




    }

    func add(observer: StoreObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.append(observer)
        }
    }

    func identifiers(filter: String? = nil, completion: @escaping (Result<[String], StoreError>) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            let filter = filter ?? ""
            let items = filter.isEmpty ? Array(self.items.values) : self.items.values.filter { $0.title.lowercased().contains(filter.lowercased()) }
            let identifiers = items.sorted(by: { $0.title < $1.title }).map { $0.identifier }
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
        do {
            let object = try NSKeyedArchiver.archivedData(withRootObject: self.items, requiringSecureCoding: true)
            try object.write(to: self.path, options: .atomic)
        } catch {
            print("Failed to write store with error \(error)")
        }
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
    }

}
