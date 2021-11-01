// Copyright (c) 2020-2021 InSeven Limited
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

import SwiftUI

import BookmarksCore

struct SettingsView: View {

    enum SheetType {
        case about
    }

    enum AlertType {
        case error(error: Error)
        case success(message: String)
    }

    @Environment(\.manager) var manager: BookmarksManager
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var settings: Settings
    @State var sheet: SheetType?
    @State var alert: AlertType?

    var body: some View {
        VStack {
            Form {
                Section {
                    Toggle("Use In-App Browser", isOn: $settings.useInAppBrowser)
                }
                Section("Thumbnails") {
                    Picker("Concurrent Downloads", selection: $settings.maximumConcurrentThumbnailDownloads) {
                        ForEach(1 ..< 4) {
                            Text("\($0)").tag($0)
                        }
                    }
                }
                Section {
                    Button(action: {
                        manager.imageCache.clear() { (result) in
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
                Section {
                    Button(action: { sheet = .about }) {
                        Text("About Bookmarks")
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
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .about:
                AboutView()
            }
        }
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

extension SettingsView.SheetType: Identifiable {
    public var id: String {
        switch self {
        case .about:
            return "about"
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
