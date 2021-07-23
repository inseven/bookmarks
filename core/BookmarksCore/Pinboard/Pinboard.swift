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

    enum PinboardError: Error {
        case inconsistentState(message: String)
    }

    fileprivate enum Path: String {
        case posts_all = "posts/all"
        case posts_delete = "posts/delete"
        case tags_rename = "tags/rename"
    }

    fileprivate let baseUrl = "https://api.pinboard.in/v1/"

    let token: String

    public init(token: String) {
        self.token = token
    }

    fileprivate func serviceUrl(_ path: Path, parameters: [String:String] = [:]) throws -> URL {
        let baseUrl = try self.baseUrl.asUrl()
        let url = baseUrl.appendingPathComponent(path.rawValue)
        var components = try url.asComponents()
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "auth_token", value: token),
            URLQueryItem(name: "format", value: "json"),
        ]
        parameters.forEach { name, value in
            queryItems.append(URLQueryItem(name: name, value: value))
        }
        components.queryItems = queryItems
        return try components.asUrl()
    }

    // TODO: Consider using a promise for this?
    fileprivate func fetch<T>(path: Path,
                              parameters: [String: String] = [:],
                              completion: @escaping (Result<T, Error>) -> Void,
                              transform: @escaping (Data) throws -> T) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        do {
            let url = try serviceUrl(path, parameters: parameters)
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard let data = data else {
                    guard let error = error else {
                        completion(.failure(PinboardError.inconsistentState(message: "Missing error when processing URL completion")))
                        return
                    }
                    completion(.failure(error))
                    return
                }
                // TODO: Handle HTTP error codes in the Pinboard API responses #135
                //       https://github.com/inseven/bookmarks/issues/135
                do {
                    let result = try transform(data)
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
            return
        }
    }

    public func posts_all(completion: @escaping (Result<[Post], Error>) -> Void) {
        self.fetch(path: .posts_all, completion: completion) { data in
            return try JSONDecoder().decode([Post].self, from: data)
        }
    }

    public func posts_delete(url: URL, completion: @escaping (Result<Bool, Swift.Error>) -> Void) {
        let parameters = [
            "url": url.absoluteString,
        ]
        self.fetch(path: .posts_delete, parameters: parameters, completion: completion) { _ in
            return true
        }
    }

    public func tags_rename(_ old: String, to new: String, completion: @escaping (Result<Bool, Swift.Error>) -> Void) {
        let parameters = [
            "old": old,
            "new": new,
        ]
        self.fetch(path: .tags_rename, parameters: parameters, completion: completion) { _ in
            return true
        }
    }

}
