//
//  ShareViewController.swift
//  Bookmarks Share Extension
//
//  Created by Jason Barrie Morley on 29/06/2023.
//  Copyright © 2023 InSeven Limited. All rights reserved.
//


import UIKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

import BookmarksCore

// TODO: MainActor assertions
class ShareExtensionModel: ObservableObject {

    static let shared = ShareExtensionModel()

    @Published var items: [NSExtensionItem] = []
    @Published var urls: [URL] = []

    init() {
    }

}

struct ContentView: View {

    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var extensionModel: ShareExtensionModel

    var body: some View {
        List {
            ForEach(extensionModel.urls) { item in
                Text(item.description)
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {

                }
            }
        }
        .dismissable(.cancel)
    }

}

struct RootView: View {

    @ObservedObject var extensionModel: ShareExtensionModel

    var body: some View {
        NavigationView {
            ContentView()
                .environmentObject(extensionModel)
        }
    }

}

class ShareViewController: UIHostingController<RootView> {

    required init?(coder aDecoder: NSCoder) {
        super.init(rootView: RootView(extensionModel: ShareExtensionModel.shared))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadItems()
    }

    private func loadItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }
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

extension NSItemProvider {

    func item(typeIdentifier: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: error)
            }
        }
    }

}
