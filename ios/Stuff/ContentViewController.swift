//
//  ContentViewController.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 28/10/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

class ContentViewController: UIHostingController<ContentView> {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: ContentView(store: AppDelegate.shared.store))
    }

}
