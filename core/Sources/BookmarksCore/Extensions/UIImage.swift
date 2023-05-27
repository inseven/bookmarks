// Copyright (c) 2020-2023 InSeven Limited
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

import Combine

#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension SafeImage {

    convenience init?(contentsOf url: URL) {
        guard let data = try? Data.init(contentsOf: url) else {
            return nil
        }
        self.init(data: data)
    }

    func resize(height: CGFloat) -> Future<SafeImage, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .background).async {

                #if os(iOS)

                let scale = height / self.size.height
                let width = self.size.width * scale
                UIGraphicsBeginImageContext(CGSize(width: width, height: height))
                defer { UIGraphicsEndImageContext() }
                self.draw(in:CGRect(x:0, y:0, width: width, height:height))
                guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                    promise(.failure(BookmarksError.resizeFailure))
                    return
                }
                promise(.success(image))

                #else

                // TODO: Actually implement this.
                promise(.success(self))

                #endif
            }
        }

    }

}

#if os(macOS)

extension NSImage {

    func pngData() -> Data? {
        guard let representation = tiffRepresentation else {
            return nil
        }
        let imageRep = NSBitmapImageRep(data: representation)
        let pngData = imageRep?.representation(using: .png, properties: [:])
        return pngData
    }

}

#endif
