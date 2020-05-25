//
//  Updater.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation

class Updater {

    let store: Store
    let token: String

    init(store: Store, token: String) {
        self.store = store
        self.token = token
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
                    guard let url = post.href else {
                        continue
                    }
                    items.append(Item(identifier: post.hash,
                                      title: post.description ?? "",
                                      url: url,
                                      tags: post.tags))
                }
                self.store.save(items: items) { (success) in
                    print("Saved items with success \(success)")
                }
            }
        }
    }

}
