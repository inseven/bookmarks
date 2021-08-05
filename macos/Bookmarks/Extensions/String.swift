//
//  String.swift
//  TokenFields
//
//  Created by Jason Barrie Morley on 05/08/2021.
//

import SwiftUI

// https://gist.github.com/iandundas/59303ab6fd443b5eec39
extension String {

    static func randomEmoji() -> String {
        let range = [UInt32](0x1F601...0x1F64F)
        let ascii = range[Int(drand48() * (Double(range.count)))]
        let emoji = UnicodeScalar(ascii)?.description
        return emoji!
    }

}
