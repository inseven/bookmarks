//
//  SettingsView.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

struct SettingsView: View {

    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var settings: Settings

    var body: some View {
        VStack {
            Form {
                Section() {
                    TextField("Pinboard API Key", text: $settings.pinboardApiKey)
                }
                Section() {
                    Toggle("Use In-App Browser", isOn: $settings.useInAppBrowser)
                }
                Section(header: Text("Thumbnails")) {
                    Picker("Concurrent Downloads", selection: $settings.maximumConcurrentThumbnailDownloads) {
                        ForEach(1 ..< 4) {
                            Text("\($0)").tag($0)
                        }
                    }
                }
                Section() {
                    Button(action: {
                        AppDelegate.shared.imageCache.clear() { (result) in
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
                            }
                        }
                    }) {
                        Text("Clear Cache").foregroundColor(.red)
                    }
                }
            }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("Done")
                .fontWeight(.regular)
        })
    }
}
