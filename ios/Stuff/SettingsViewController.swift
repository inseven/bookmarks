//
//  SettingsViewController.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import UIKit
import SwiftUI

final class SettingsViewState: ObservableObject {

    @Published var enabled: Bool = true

}

class SettingsViewController: UIHostingController<SettingsView> {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: SettingsView(settings: Settings()))
        self.rootView.delegate = self
    }

    override func viewDidLoad() {
        self.rootView.delegate = self
    }

}

extension SettingsViewController: SettingsViewDelegate {

    func clearCache() {
        dispatchPrecondition(condition: .onQueue(.main))
        let delegate = UIApplication.shared.delegate as! AppDelegate
        delegate.imageCache.clear() { (result) in
            DispatchQueue.main.async {
                // TODO:
//                self.collectionView.reloadData()
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

}
