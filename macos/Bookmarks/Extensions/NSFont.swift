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
