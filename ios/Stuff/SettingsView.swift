//
//  SettingsView.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 29/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

protocol SettingsViewDelegate: NSObject {
    func clearCache()
}

struct SettingsView: View {

    @ObservedObject var settings: Settings
    weak var delegate: SettingsViewDelegate?

    var body: some View {
        VStack {
            Form {
                Section() {
                    TextField("Pinboard API Key", text: $settings.pinboardApiKey)
                }
                Section() {
                    Toggle("Use In-App Browser", isOn: $settings.useInAppBrowser)
                }
                Section() {
                    Button(action: {
                        guard let delegate = self.delegate else {
                            return
                        }
                        delegate.clearCache()
                    }) {
                        Text("Clear Cache").foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {

    static var previews: some View {
        SettingsView(settings: Settings())
    }
}