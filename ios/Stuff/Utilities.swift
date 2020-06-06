//
//  Utilities.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 24/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Combine
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

class Utilities {

    static func completion<T, U>(on queue: DispatchQueue, completion: @escaping (Result<T, U>) -> Void) -> (Result<T, U>) -> Void {
        return { (result) in
            queue.async {
                completion(result)
            }
        }
    }

    static func meta(for url: URL) -> Future<UIImage, Error> {
        return Future { (promise) in
            simpleThumbnail(for: url) { (result) in
                promise(result)
            }
        }
    }

}

func simpleThumbnail(for url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
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
        guard let image = document.openGraphImage else {
            completion(.failure(OpenGraphError.invalidArgument(message: "Failed to find image")))
            return
        }
        completion(.success(image))
    }
    task.resume()
}
