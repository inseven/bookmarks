//
//  Updater.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation

protocol UpdaterObserver: AnyObject {

}

class Updater {

    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue
    let store: Store
    let token: String
    var observers: [UpdaterObserver] // Synchronized on syncQueue

    init(store: Store, token: String) {
        self.store = store
        self.token = token
        self.syncQueue = DispatchQueue(label: "syncQueue")
        self.targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
        self.observers = []
    }

    func add(observer: UpdaterObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            self.observers.append(observer)
        }
    }

    func remove(observer: UpdaterObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            self.observers.removeAll { ( $0 === observer ) }
        }
    }

    func start() {
        Pinboard(token: self.token).fetch { [weak self] (result) in
            switch (result) {
            case .failure(let error):
                print("Failed to fetch the posts with error \(error)")
            case .success(let posts):
                guard let self = self else {
                    return
                }
                var items: [Item] = []
                for post in posts {
                    guard
                        let url = post.href,
                        let date = post.time else {
                            continue
                    }
                    items.append(Item(identifier: post.hash,
                                      title: post.description ?? "",
                                      url: url,
                                      tags: post.tags,
                                      date: date))
                }
                self.store.save(items: items) { (success) in
                    print("Saved items with success \(success)")
                }
            }
        }
    }

}
