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
    var uuid: UUID?
}

enum OpenGraphError: Error {
    case invalidArgument(message: String)
}

enum Section : CaseIterable {
  case one
}

class ViewController: UIViewController  {

    private lazy var dataSource = makeDataSource()
    private lazy var searchController = makeSearchController()
    @IBOutlet var collectionView: UICollectionView!

    var thumbnailManager: ThumbnailManager!
    var store: Store!

    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, String> {
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { (collectionView, indexPath, identifier) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell
            cell.titleLabel.text = nil
            cell.imageView.image = nil
            let uuid = UUID()
            cell.uuid = uuid
            self.store.item(identifier: identifier) { (result) in
                switch result {
                case .failure(let error):
                    print("Failed to fetch item with error \(error)")
                case .success(let item):
                    guard cell.uuid == uuid else {
                        return
                    }
                    cell.titleLabel.text = !item.title.isEmpty ? item.title : item.url.absoluteString
                    self.thumbnailManager.thumbnail(for: item) { (result) in
                        switch result {
                        case .failure(let error):
                            print("Failed to get thumbnail for \(item.url) with error \(error)")
                        case .success(let image):
                            DispatchQueue.main.async {
                                guard cell.uuid == uuid else {
                                    return
                                }
                                cell.imageView.image = image
                            }
                        }
                    }
                }
            }
            return cell
        }
    }

    func makeSearchController() -> UISearchController {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        return searchController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let delegate = UIApplication.shared.delegate as! AppDelegate
        store = delegate.store
        thumbnailManager = delegate.thumbnailManager
        store.add(observer: self)

        collectionView.dataSource = dataSource
        navigationItem.searchController = searchController
    }

    func update() {
        store.identifiers(filter: searchController.searchBar.searchTextField.text) { (result) in
            switch result {
            case .failure(let error):
                print("Failed to fetch store identifiers with error \(error)")
            case .success(let identifiers):
                var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
                snapshot.appendSections(Section.allCases)
                snapshot.appendItems(identifiers, toSection: .one)
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }

}

extension ViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        update()
    }

}

extension ViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let identifier = dataSource.itemIdentifier(for: indexPath) {
            self.store.item(identifier: identifier) { (result) in
                switch result {
                case .failure(let error):
                    print("Failed to get item with error \(error)")
                case .success(let item):
                    UIApplication.shared.open(item.url)
                }
            }
        }
    }

}

extension ViewController: StoreObserver {

    func storeDidUpdate(store: Store) {
        update()
    }

}
