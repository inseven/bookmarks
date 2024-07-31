// Copyright (c) 2020-2024 Jason Morley
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

public struct FaviconImage: View {

    public struct LayoutMetrics {
        public static let size = CGSize(width: 16, height: 16)
    }

    private var url: URL

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
//        if let url = url.faviconURL {
//            AsyncImage(url: url) { image in
//                image
//                    .resizable()
//                    .frame(width: LayoutMetrics.size.width, height: LayoutMetrics.size.height)
//            } placeholder: {
//                Image(systemName: "globe")
//                    .resizable()
//                    .foregroundColor(.secondary)
//                    .frame(width: LayoutMetrics.size.width, height: LayoutMetrics.size.height)
//            }
//        } else {
            Image(systemName: "globe")
                .resizable()
                .foregroundColor(.secondary)
                .frame(width: LayoutMetrics.size.width, height: LayoutMetrics.size.height)
//        }
    }

}
