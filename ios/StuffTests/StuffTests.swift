//
//  StuffTests.swift
//  StuffTests
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import XCTest
@testable import Stuff

class StuffTests: XCTestCase {

    func thumbnail(for url: String) -> UIImage? {

        let expectation = self.expectation(description: "Download thumbnail")
        guard let url = URL(string: url) else {
            XCTFail("Failed to parse URL")
            return nil
        }

        var image: UIImage?
        downloadThumbnail(for: url) { (result) in
            defer { expectation.fulfill() }
            guard case .success(let blockImage) = result else {
                return
            }
            image = blockImage
            XCTAssertNotNil(image)
        }
        self.wait(for: [expectation], timeout: 5)
        return image
    }

    func testThumbnail() {

        XCTAssertNotNil(thumbnail(for: "https://www.raspberrypi.org/products/raspberry-pi-high-quality-camera/"))
        XCTAssertNil(thumbnail(for: "http://lesscss.org"))
        XCTAssertNotNil(thumbnail(for: "http://2064.io"))

    }

}
