//
//  Utilities.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

func downloadThumbnail(for url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Downloading image for \(url)...")

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
        guard let elements = doc.search(withXPathQuery: "//meta[@property='og:image']/@content") as? [TFHppleElement] else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")))
            return
        }
        guard let element = elements.first else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to find open graph image tag")))
            return
        }
        guard let content = element.content else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Image tag had no content")))
            return
        }
        guard let components = URLComponents(string: content) else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to create URL components")))
            return
        }
        guard let imageURL = components.url(relativeTo: url) else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Invalid image URL")))
            return
        }
        guard let imageData = try? Data.init(contentsOf: imageURL) else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to download image")))
            return
        }
        guard let image = UIImage.init(data: imageData) else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Unable to construct image")))
            return
        }
        completion(.success(image))
    }
    task.resume()

}
