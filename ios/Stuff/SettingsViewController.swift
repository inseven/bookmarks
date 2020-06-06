//
//  SettingsViewController.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import UIKit
import SwiftUI

protocol SettingsViewControllerDelegate: AnyObject {
    func settingsViewControllerDidFinish(_ controller: SettingsViewController)
}

final class SettingsViewState: ObservableObject {
    @Published var enabled: Bool = true
}

class SettingsViewController: UIHostingController<SettingsView> {

    weak var delegate: SettingsViewControllerDelegate?

    required init?(coder aDecoder: NSCoder) {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        super.init(coder: aDecoder, rootView: SettingsView(settings: delegate.settings))
        self.rootView.delegate = self
    }

    override func viewDidLoad() {
        self.rootView.delegate = self
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }

    @objc func doneTapped() {
        guard let delegate = self.delegate else {
            return
        }
        delegate.settingsViewControllerDidFinish(self)
    }

}

extension SettingsViewController: SettingsViewDelegate {

    func clearCache() {
        dispatchPrecondition(condition: .onQueue(.main))
        let delegate = UIApplication.shared.delegate as! AppDelegate
        delegate.imageCache.clear() { (result) in
            DispatchQueue.main.async {
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
