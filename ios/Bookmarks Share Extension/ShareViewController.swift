// Copyright (c) 2020-2023 InSeven Limited
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

import BookmarksCore

class ShareViewController: UIHostingController<RootView> {

    required init?(coder aDecoder: NSCoder) {
        super.init(rootView: RootView(extensionModel: ShareExtensionModel.shared))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadItems()
    }

    private func reloadItems() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }
        ShareExtensionModel.shared.urls = []
        extensionItems
            .compactMap { $0.attachments }
            .reduce([], +)
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
            .forEach { itemProvider in
                itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) { object, error in
                    DispatchQueue.main.async {
                        guard let url = object as? URL else {
                            return
                        }
                        ShareExtensionModel.shared.urls.append(url)
                    }
                }
            }
    }

}
