// Copyright (c) 2020-2022 InSeven Limited
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
import Foundation

#if os(iOS)
import UIKit
#endif

enum OpenGraphError: Error {
    case invalidArgument(message: String)
}

class Utilities {

    static func simpleThumbnail(for url: URL, completion: @escaping (Result<SafeImage, Error>) -> Void) {
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

    static func completion<T, U>(on queue: DispatchQueue,
                                 completion: @escaping (Result<T, U>) -> Void) -> (Result<T, U>) -> Void {
        return { (result) in
            queue.async {
                completion(result)
            }
        }
    }

    static func meta(for url: URL) -> Future<SafeImage, Error> {
        return Future { (promise) in
            simpleThumbnail(for: url) { (result) in
                promise(result)
            }
        }
    }

}
