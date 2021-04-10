// Copyright (c) 2020-2021 InSeven Limited
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

import Foundation

public class Pinboard {

    enum Error: Swift.Error {
        case invalidURL(message: String)
        case invalidResponse(message: String)
        case inconsistentState(message: String)
    }

    fileprivate let baseURL = "https://api.pinboard.in/v1/"

    fileprivate enum Path: String {
        case posts_all = "posts/all"
    }

    let token: String

    public init(token: String) {
        self.token = token
    }

    public func posts_all(completion: @escaping (Result<[Post], Swift.Error>) -> Void) {
        guard let base = URL(string: baseURL) else {
            DispatchQueue.global(qos: .default).async {
                completion(.failure(Error.invalidURL(message: "Unable to construct parse base URL")))
            }
            return
        }
        let posts = base.appendingPathComponent(Path.posts_all.rawValue)
        guard var components = URLComponents(string: posts.absoluteString) else {
            DispatchQueue.global(qos: .default).async {
                completion(.failure(Error.invalidURL(message: "Unable to parse URL components")))
            }
            return
        }
        components.queryItems = [
            URLQueryItem(name: "auth_token", value: token),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else {
            DispatchQueue.global(qos: .default).async {
                completion(.failure(Error.invalidURL(message: "Unable to construct URL from components")))
            }
            return
        }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                guard let error = error else {
                    completion(.failure(Error.inconsistentState(message: "Missing error when processing URL completion")))
                    return
                }
                completion(.failure(error))
                return
            }
            do {
                let posts = try JSONDecoder().decode([Post].self, from: data)
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

}
