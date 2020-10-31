//
//  View+Utilities.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 31/10/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import SwiftUI

extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}
