//
//  LicenseView.swift
//  Anytime
//
//  Created by Jason Barrie Morley on 03/10/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

struct LicenseView: View {

    var name: String
    var filename: String

    var body: some View {
        ScrollView {
            Text(contentsOf: filename)
                .padding()
        }
        .navigationTitle(name)
    }

}
