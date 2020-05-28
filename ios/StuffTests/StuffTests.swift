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
        self.wait(for: [expectation], timeout: 20)
        return image
    }

    func testThumbnail() {
        XCTAssertNotNil(thumbnail(for: "https://www.raspberrypi.org/products/raspberry-pi-high-quality-camera/"))
        XCTAssertNotNil(thumbnail(for: "http://2064.io"))
        XCTAssertNotNil(thumbnail(for: "https://eu.vibram.com/en/shop/fivefingers/men/kso-mens/M14.html?dwvar_M14_color=Black%20%2F%20Black#start=1"))
        XCTAssertNotNil(thumbnail(for: "https://www.amazon.com/dp/B0838WTFD1/ref=cm_sw_r_cp_api_i_bnXZEb3138AZP"))
        XCTAssertNil(thumbnail(for: "http://lesscss.org"))
    }

    func testAmazonThumbnail() {
        let expectation = self.expectation(description: "Download thumbnail")
        let downloader = WebViewDownloader(url: URL(string: "https://www.amazon.com/dp/B0838WTFD1/ref=cm_sw_r_cp_api_i_bnXZEb3138AZP")!)
        downloader.start { (result) in
            switch result {
            case .success(let url):
                print("url => \(url)")
            case .failure:
                XCTFail("Failed to find image!")
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 20)
    }

    // TODO: URL components resolving.

    func testUnsafeURLComponents() {
        let components = URLComponents(unsafeString: "https://eu.vibram.com/dw/image/v2/AAWR_PRD/on/demandware.static/-/Sites-vbi-apparel-footwear/default/dw10645955/images/M14/SS16_M_KSO_BLACKBLACK_MAIN copy.jpg?sh=1000")
        XCTAssertNotNil(components)
    }

}
