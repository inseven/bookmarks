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
    @IBOutlet weak var imageView: UIImageView!
}

enum OpenGraphError: Error {
    case invalidArgument(message: String)
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

    func image(for url: URL, completion: @escaping (Result<UIImage>) -> Void) {

        // Force HTTPS.
        guard var components = URLComponents(string: url.absoluteString) else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to create URL components")))
            return
        }

        components.scheme = "https"

        guard let secureUrl = components.url else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to create secure URL")))
            return
        }

        let task = URLSession.shared.dataTask(with: secureUrl) { (data, response, error) in
            guard let data = data else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to get contents of URL for cell")))
                return
            }
            guard let doc = TFHpple(htmlData: data) else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to parse the data")))
                return
            }
            guard let elements = doc.search(withXPathQuery: "//meta[@property='og:image']/@content") as? [TFHppleElement] else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")))
                return
            }
            guard let element = elements.first else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")))
                return
            }
            guard let content = element.content else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Image tag had no content")))
                return
            }
            guard let components = URLComponents(string: content) else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to create URL components")))
                return
            }
            guard let imageURL = components.url(relativeTo: secureUrl) else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Invalid image URL")))
                return
            }
            guard let imageData = try? Data.init(contentsOf: imageURL) else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to download image")))
                return
            }
            guard let image = UIImage.init(data: imageData) else {
                completion(.failure(OpenGraphError.invalidArgument(message: "Unable to construct image")))
                return
            }
            completion(.success(image))
        }
        task.resume()

    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell
        let post = self.posts[indexPath.row]
        cell.titleLabel.text = post.description
        cell.imageView.image = nil

        guard let url = post.href else {
            print("Unable to get URL for cell")
            return cell
        }

        image(for: url) { (result) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                switch (result) {
                case .success(let image):
                    // TODO: What happens if the cell locations have changed?
                    guard let cell = self.collectionView.cellForItem(at: indexPath) as? Cell else {
                        return
                    }
                    cell.imageView.image = image
                case .failure(let error):
                    print("Failed to download image for URL '\(url)' with error '\(error)'")
                }
            }
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // TODO: Rename href to URL and make none-nullable
        let post = self.posts[indexPath.row]
        UIApplication.shared.open(post.href!)
    }

}

