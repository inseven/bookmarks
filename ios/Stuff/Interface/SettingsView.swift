//
//  SettingsView.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

struct SettingsView: View {

    enum AlertType {
        case error(error: Error)
        case success(message: String)
    }

    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var settings: Settings
    @State var alert: AlertType?

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
                                switch result {
                                case .success:
                                    alert = .success(message: "Successfully cleared the cache!")
                                case .failure(let error):
                                    alert = .error(error: error)
                                }
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
        .alert(item: $alert) { alert in
            switch alert {
            case .error(let error):
                return Alert(title: Text("Error"), message: Text(error.localizedDescription))
            case .success(let message):
                return Alert(title: Text("Success"), message: Text(message))
            }
        }
    }
}

extension SettingsView.AlertType: Identifiable {
    public var id: String {
        switch self {
        case .error:
            return "error"
        case .success:
            return "success"
        }
    }
}
