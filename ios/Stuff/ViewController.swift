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
    var downloader: Downloader?
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
    var imageCache: ImageCache!

    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, String> {
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { (collectionView, indexPath, identifier) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell

            cell.titleLabel.text = nil
            cell.imageView.image = nil
            if let downloader = cell.downloader {
                downloader.cancel()
                cell.downloader = nil
            }

            cell.layer.masksToBounds = true
            cell.layer.cornerRadius = 10
            cell.layer.cornerCurve = .continuous

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
                    let downloader = self.thumbnailManager.thumbnail(for: item) { (result) in
                        switch result {
                        case .failure:
                            return
                        case .success(let image):
                            DispatchQueue.main.async {
                                guard cell.uuid == uuid else {
                                    return
                                }
                                cell.imageView.image = image
                            }
                        }
                    }
                    cell.downloader = downloader
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
        imageCache = delegate.imageCache
        store.add(observer: self)

        collectionView.dataSource = dataSource
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        collectionView.collectionViewLayout = createLayout()

        self.navigationController?.navigationBar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.sampleTapGestureTapped(recognizer:))))
    }

    @IBAction func emptyCache(_ sender: Any) {
        imageCache.clear() { (result) in
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                var message = ""
                switch result {
                case .success:
                    message = "Successfully cleared the cache!"
                case .failure(let error):
                    message = "Failed to clear the cache with error \(error)"
                }
                let alert = UIAlertController(title: "Cache", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    @objc func sampleTapGestureTapped(recognizer: UITapGestureRecognizer) {
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                              heightDimension: .fractionalHeight(1))
        let spacing: CGFloat = 20.0
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: spacing)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(280))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item, item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: spacing, bottom: 0, trailing: 0)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: 0.0, bottom: 0.0, trailing: 0.0)

        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
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

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard
            let cell = cell as? Cell,
            let downloader = cell.downloader else {
            return
        }
        downloader.cancel()
    }

}

extension ViewController: StoreObserver {

    func storeDidUpdate(store: Store) {
        update()
    }

}
