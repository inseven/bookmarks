// Copyright (c) 2020-2021 Jason Barrie Morley
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
@testable import Bookmarks

class StuffTests: XCTestCase {

    // TODO: Reinstate this code.
//    func thumbnail(for url: String) -> UIImage? {
//
//        let expectation = self.expectation(description: "Download thumbnail")
//        guard let url = URL(string: url) else {
//            XCTFail("Failed to parse URL")
//            return nil
//        }
//
//        var image: UIImage?
//        downloadThumbnail(for: url) { (result) in
//            defer { expectation.fulfill() }
//            guard case .success(let blockImage) = result else {
//                return
//            }
//            image = blockImage
//            XCTAssertNotNil(image)
//        }
//        self.wait(for: [expectation], timeout: 20)
//        return image
//    }
//
//    func testThumbnail() {
//        XCTAssertNotNil(thumbnail(for: "https://www.raspberrypi.org/products/raspberry-pi-high-quality-camera/"))
//        XCTAssertNotNil(thumbnail(for: "http://2064.io"))
//        XCTAssertNotNil(thumbnail(for: "https://eu.vibram.com/en/shop/fivefingers/men/kso-mens/M14.html?dwvar_M14_color=Black%20%2F%20Black#start=1"))
//        XCTAssertNotNil(thumbnail(for: "https://www.amazon.com/dp/B0838WTFD1/ref=cm_sw_r_cp_api_i_bnXZEb3138AZP"))
//        XCTAssertNil(thumbnail(for: "http://lesscss.org"))
//    }

    func testAmazonThumbnail() {
        let expectation = self.expectation(description: "Download thumbnail")
        guard let url = URL(string: "https://www.amazon.com/dp/B0838WTFD1/ref=cm_sw_r_cp_api_i_bnXZEb3138AZP") else {
            XCTFail()
            return
        }
        let downloader = WebViewDownloader(url: url) { (result) in
            switch result {
            case .success(let url):
                print("url => \(url)")
            case .failure:
                XCTFail("Failed to find image!")
            }
            expectation.fulfill()
        }
        downloader.start()
        self.wait(for: [expectation], timeout: 20)
    }

    // TODO: URL components resolving.

    func testUnsafeURLComponents() {
        let components = URLComponents(unsafeString: "https://eu.vibram.com/dw/image/v2/AAWR_PRD/on/demandware.static/-/Sites-vbi-apparel-footwear/default/dw10645955/images/M14/SS16_M_KSO_BLACKBLACK_MAIN copy.jpg?sh=1000")
        XCTAssertNotNil(components)
    }


    //            https://32blit.com
    //            <link rel="icon" type="image/png" href="/images/favicon.png" />
    //            <script type="application/ld+json">{"@type":"WebSite","url":"https://32blit.com/","headline":"32blit – The open, retro-inspired, handheld console for creators.","name":"32blit – The open, retro-inspired, handheld console for creators.","description":"32blit is a handheld console that either runs C/C++ or a customised version of Lua at its core. It comes pre-loaded with our full programming library that makes graphics and games programming a breeze.","@context":"https://schema.org"}</script>

    //            https://feedafever.com
    //            <link rel="shortcut icon" type="image/png" href="/favicon.png">

    //            http://sonyahammons.com
    //            <link rel="icon" href="http://sonyahammons.com/wp-content/uploads/2017/10/s.jpg" sizes="32x32"/>
    //            <link rel="icon" href="http://sonyahammons.com/wp-content/uploads/2017/10/s.jpg" sizes="192x192"/>
    //            <link rel="apple-touch-icon-precomposed" href="http://sonyahammons.com/wp-content/uploads/2017/10/s.jpg"/>
    //            <meta name="msapplication-TileImage" content="http://sonyahammons.com/wp-content/uploads/2017/10/s.jpg"/>

    //            https://www.adafruit.com/product/1289
    //            <link rel="mask-icon" href="https://cdn-shop.adafruit.com/static/adafruit_favicon.svg" color="#000000">
    //            <link rel="apple-touch-icon" sizes="57x57" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-57x57.png">
    //            <link rel="apple-touch-icon" sizes="114x114" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-114x114.png">
    //            <link rel="apple-touch-icon" sizes="72x72" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-72x72.png">
    //            <link rel="apple-touch-icon" sizes="144x144" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-144x144.png">
    //            <link rel="apple-touch-icon" sizes="60x60" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-60x60.png">
    //            <link rel="apple-touch-icon" sizes="120x120" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-120x120.png">
    //            <link rel="apple-touch-icon" sizes="76x76" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-76x76.png">
    //            <link rel="apple-touch-icon" sizes="152x152" href="https://cdn-shop.adafruit.com/static/apple-touch-icon-152x152.png">
    //            <link rel="icon" type="image/png" href="https://cdn-shop.adafruit.com/static/favicon-196x196.png" sizes="196x196">
    //            <link rel="icon" type="image/png" href="https://cdn-shop.adafruit.com/static/favicon-160x160.png" sizes="160x160">
    //            <link rel="icon" type="image/png" href="https://cdn-shop.adafruit.com/static/favicon-96x96.png" sizes="96x96">
    //            <link rel="icon" type="image/png" href="https://cdn-shop.adafruit.com/static/favicon-16x16.png" sizes="16x16">
    //            <link rel="icon" type="image/png" href="https://cdn-shop.adafruit.com/static/favicon-32x32.png" sizes="32x32">
    //            <meta name="msapplication-TileColor" content="#1a1919">
    //            <meta name="msapplication-TileImage" content="https://cdn-shop.adafruit.com/static/mstile-144x144.png">

}
