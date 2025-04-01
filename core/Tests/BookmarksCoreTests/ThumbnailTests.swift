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

import XCTest
@testable import BookmarksCore

class ThumbnailTests: XCTestCase {

    func thumbnail(for url: String) -> SafeImage? {
        print("Fetching thumbnail for '\(url)'...")

        let expectation = self.expectation(description: "Download thumbnail for '\(url)'")
        guard let url = URL(string: url) else {
            XCTFail("Failed to parse URL")
            return nil
        }

        var image: SafeImage?
        Utilities.simpleThumbnail(for: url) { (result) in
            defer { expectation.fulfill() }
            guard case .success(let blockImage) = result else {
                return
            }
            image = blockImage
            XCTAssertNotNil(image)
        }
        self.wait(for: [expectation], timeout: 20)
        return image
    }

    func testThumbnail() {
        XCTAssertNotNil(thumbnail(for: "http://2064.io"))
        XCTAssertNil(thumbnail(for: "http://lesscss.org"))
    }

    func testUnsafeURLComponents() {
        let components = URLComponents(unsafeString: "https://eu.vibram.com/dw/image/v2/AAWR_PRD/on/demandware.static/-/Sites-vbi-apparel-footwear/default/dw10645955/images/M14/SS16_M_KSO_BLACKBLACK_MAIN copy.jpg?sh=1000")
        XCTAssertNotNil(components)
    }

}
