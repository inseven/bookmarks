//
//  ViewController.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import Combine
import SafariServices
import UIKit

class Cell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    var uuid: UUID?
    var future: AnyCancellable?
}

enum CollectionSection : CaseIterable {
  case one
}

class CancellableSearchController: UISearchController {

    lazy var customSearchBar = CancellableSarchBar()
    override var searchBar: UISearchBar { customSearchBar }

}

class CancellableSarchBar: UISearchBar {

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancel))]
    }

    @objc func cancel() {
        self.searchTextField.text = ""
        self.delegate?.searchBarCancelButtonClicked?(self)
    }

}

class ViewController: UIViewController  {

    private lazy var dataSource = makeDataSource()
    private lazy var searchController = makeSearchController()
    @IBOutlet var collectionView: UICollectionView!

    var thumbnailManager: ThumbnailManager!
    var store: Store!
    var imageCache: ImageCache!
    var settings: Settings!

    func makeDataSource() -> UICollectionViewDiffableDataSource<CollectionSection, String> {
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { (collectionView, indexPath, identifier) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell

            cell.titleLabel.text = nil
            cell.imageView.image = nil
            if let future = cell.future {
                future.cancel()
                cell.future = nil
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
                    cell.future = self.thumbnailManager.thumbnail(for: item)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { (completion) in
                            if case .failure(let error) = completion {
                                print("Failed to download thumbnail with error \(error)")
                            }
                        }, receiveValue: { (image) in
                            guard cell.uuid == uuid else {
                                return
                            }
                            cell.imageView.image = image
                        })
                }
            }
            return cell
        }
    }

    func makeSearchController() -> UISearchController {
        let searchController = CancellableSearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        return searchController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let delegate = UIApplication.shared.delegate as! AppDelegate
        store = delegate.store
        thumbnailManager = delegate.thumbnailManager
        imageCache = delegate.imageCache
        settings = delegate.settings
        store.add(observer: self)

        navigationController?.navigationBar.prefersLargeTitles = true

        collectionView.dataSource = dataSource
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        collectionView.collectionViewLayout = createLayout(size: view.bounds.size)
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == UIMenuSystem.main else { return }
        let find = UIKeyCommand(title: "Search", image: nil, action: #selector(ViewController.findShortcut), input: "f", modifierFlags: [.command])
        let newMenu = UIMenu(title: "File", options: .displayInline, children: [find])
        builder.insertChild(newMenu, atStartOfMenu: .file)
    }

    override var performsActionsWhilePresentingModally: Bool { false }
    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(title: "Find", image: nil, action: #selector(findShortcut), input: "f", modifierFlags: [.command])]
    }

    @objc func findShortcut() {
        searchController.searchBar.becomeFirstResponder()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) in
            self.collectionView.setCollectionViewLayout(self.createLayout(size: size), animated: context.isAnimated)
        }, completion: nil)
    }

    private func createLayout(size: CGSize) -> UICollectionViewLayout {
        let columns =  Int(floor(size.width / 300.0))
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                              heightDimension: .fractionalHeight(1))
        let spacing: CGFloat = 20.0
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: spacing)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(280))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
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
                var snapshot = NSDiffableDataSourceSnapshot<CollectionSection, String>()
                snapshot.appendSections(CollectionSection.allCases)
                snapshot.appendItems(identifiers, toSection: .one)
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Settings" {
            guard
                let navigationController = segue.destination as? UINavigationController,
                let viewController = navigationController.viewControllers.first,
                let settingsViewController = viewController as? SettingsViewController else {
                print("Failed to get destination view controller")
                return
            }
            settingsViewController.delegate = self
        }
    }

}

extension ViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        update()
    }

}

extension ViewController: UISearchBarDelegate {

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchController.dismiss(animated: true, completion: nil)
    }

}

extension ViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let identifier = dataSource.itemIdentifier(for: indexPath) {
            self.store.item(identifier: identifier) { (result) in
                dispatchPrecondition(condition: .onQueue(.main))
                switch result {
                case .failure(let error):
                    print("Failed to get item with error \(error)")
                case .success(let item):
                    if self.settings.useInAppBrowser {
                        let controller = SFSafariViewController(url: item.url)
                        controller.delegate = self
                        self.present(controller, animated: true, completion: nil)
                    } else {
                        UIApplication.shared.open(item.url)
                    }
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard
            let cell = cell as? Cell,
            let future = cell.future else {
            return
        }
        future.cancel()
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        return makeFeedContextMenu(identifier: identifier)
    }


    func getShareAction(identifier: String) -> UIAction? {
        let action = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { action in
            self.store.item(identifier: identifier) { (result) in
                switch result {
                case .failure(let error):
                    print("Failed to get item with error \(error)")
                case .success(let item):
                    let activityViewController = UIActivityViewController(activityItems: [item.url], applicationActivities: nil)
                    self.present(activityViewController, animated: true, completion: nil)
                }
            }
        }
        return action
    }

    func makeFeedContextMenu(identifier: String) -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(identifier: identifier as NSCopying, previewProvider: nil, actionProvider: { [ weak self] suggestedActions in

            guard let self = self else { return nil }

            var actions = [UIAction]()

            if let shareAction = self.getShareAction(identifier: identifier) {
                actions.append(shareAction)
            }

            return UIMenu(title: "", children: actions)

        })

    }

}

extension ViewController: StoreObserver {

    func storeDidUpdate(store: Store) {
        update()
    }

}

extension ViewController: SFSafariViewControllerDelegate {

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.navigationController?.popToViewController(self, animated: true)
    }

}

extension ViewController: SettingsViewControllerDelegate {

    func settingsViewControllerDidFinish(_ controller: SettingsViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

}
