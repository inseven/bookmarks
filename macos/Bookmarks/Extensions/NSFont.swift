//
//  NSFont.swift
//  TokenFields
//
//  Created by Jason Barrie Morley on 05/08/2021.
//

import SwiftUI

extension NSFont {

    // TODO: Support fonts of specific sizes.
    static func preferredFont(forFont font: Font?) -> NSFont {
        guard let font = font else {
            return NSFont.preferredFont(forTextStyle: .body)
        }
        switch font {
        case .largeTitle:
            return NSFont.preferredFont(forTextStyle: .largeTitle)
        case .title:
            return NSFont.preferredFont(forTextStyle: .title1)
        case .title2:
            return NSFont.preferredFont(forTextStyle: .title2)
        case .title3:
            return NSFont.preferredFont(forTextStyle: .title3)
        case .headline:
            return NSFont.preferredFont(forTextStyle: .headline)
        case .subheadline:
            return NSFont.preferredFont(forTextStyle: .subheadline)
        case .body:
            return NSFont.preferredFont(forTextStyle: .body)
        case .callout:
            return NSFont.preferredFont(forTextStyle: .callout)
        case .caption:
            return NSFont.preferredFont(forTextStyle: .caption1)
        case .caption2:
            return NSFont.preferredFont(forTextStyle: .caption2)
        default:
            return NSFont.preferredFont(forTextStyle: .body)
        }
    }

}
