//
//  ViewController.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import UIKit

class Cell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
}

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
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.posts.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell
        let post = self.posts[indexPath.row]
        cell.titleLabel.text = post.description

        guard let url = post.href else {
            print("Unable to get URL for cell")
            return cell
        }

        // Download the contents of the page.
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                print("Unable to get contents of URL for cell")
                return
            }
            print(data)
        }
        task.resume()

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // TODO: Rename href to URL and make none-nullable
        let post = self.posts[indexPath.row]
        UIApplication.shared.open(post.href!)
    }

}

