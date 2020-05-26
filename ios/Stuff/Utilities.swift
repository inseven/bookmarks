//
//  Utilities.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

enum OpenGraphError: Error {
    case invalidArgument(message: String)
}

extension UIImage {

    convenience init?(contentsOf url: URL) {
        guard let data = try? Data.init(contentsOf: url) else {
            return nil
        }
        self.init(data: data)
    }

}

extension URLComponents {

    init?(unsafeString: String) {
        self.init(string: unsafeString.replacingOccurrences(of: " ", with: "%20"))
    }

}

class Document {

    let location: URL
    let contents: TFHpple

    init(location: URL, contents: TFHpple) {
        self.location = location
        self.contents = contents
    }

    var openGraphImage: UIImage? {
        get {
            if let image = try? self.image(for: "//meta[@property='og:image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@name='og:image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@name='image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@itemprop='image']/@content") {
                return image
            }
            if let image = try? self.image(for: "//meta[@name='twitter:image']/@content") {
                return image
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

            return nil
        }
    }

    func image(for query: String) throws -> UIImage {
        guard let elements = contents.search(withXPathQuery: query) as? [TFHppleElement] else {
            throw OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")
        }
        guard let element = elements.first else {
            throw OpenGraphError.invalidArgument(message: "Malformed open graph image tag")
        }
        guard let content = element.content else {
            throw OpenGraphError.invalidArgument(message: "Image tag had no content")
        }
        guard let components = URLComponents(unsafeString: content) else {
            throw OpenGraphError.invalidArgument(message: "Unable to create URL components")
        }
        guard let url = components.url(relativeTo: self.location) else {
            throw OpenGraphError.invalidArgument(message: "Inavlid image URL")
        }
        guard let image = UIImage.init(contentsOf: url) else {
            throw OpenGraphError.invalidArgument(message: "Unable to fetch image")
        }
        return image
    }

}

func downloadThumbnail(for url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {

    // TODO: Consider trying HTTPS first.

    //        // Force HTTPS.
    //        guard var components = URLComponents(string: url.absoluteString) else {
    //            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to create URL components")))
    //            return
    //        }
    //
    //        components.scheme = "https"
    //
    //        guard let secureUrl = components.url else {
    //            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to create secure URL")))
    //            return
    //        }

    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        guard let data = data else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to get contents of URL for cell")))
            return
        }
        guard let doc = TFHpple(htmlData: data) else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to parse the data")))
            return
        }

        let document = Document(location: url, contents: doc)
        if let image = document.openGraphImage {
            completion(.success(image))
            return
        }

        completion(.failure(OpenGraphError.invalidArgument(message: "Failed to find image")))

    }
    task.resume()

}
