//
//  ViewController.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import UIKit

class ViewController: UICollectionViewController {

    var posts: [Post]!

    override func viewDidLoad() {
        super.viewDidLoad()
        posts = []
        Pinboard(token: "jbmorley:08f37da5d082080ae1a5").fetch { (result) in
            switch (result) {
            case .success(let posts):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.posts = posts
                    self.collectionView.reloadData()
                }
            case .failure(let error):
                print("Failed to fetch the posts with error \(error)")
            }
        }
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.posts.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    }


}

