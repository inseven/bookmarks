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
        case unexpectedResponse
    }

    fileprivate enum Path: String {

        case postsUpdate = "posts/update"

        case postsAdd = "posts/add"
        case postsAll = "posts/all"
        case postsDelete = "posts/delete"

        case tagsDelete = "tags/delete"
        case tagsRename = "tags/rename"

    }

    fileprivate let baseUrl = "https://api.pinboard.in/v1/"
    fileprivate let token: String

    public init(token: String) {
        self.token = token
    }

    fileprivate func serviceUrl(_ path: Path, parameters: [String:String] = [:]) throws -> URL {
        let baseUrl = try self.baseUrl.url
        let url = baseUrl.appendingPathComponent(path.rawValue)
        var components = try url.components
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "auth_token", value: token),
            URLQueryItem(name: "format", value: "json"),
        ]
        parameters.forEach { name, value in
            queryItems.append(URLQueryItem(name: name, value: value))
        }
        components.queryItems = queryItems
        return try components.safeUrl
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
                print("response = \(String(describing: response))")
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

    public func postsUpdate(completion: @escaping (Result<Update, Error>) -> Void) {
        self.fetch(path: .postsUpdate, completion: completion) { data in
            try JSONDecoder().decode(Update.self, from: data)
        }
    }

    public func postsAdd(post: Post, replace: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        guard let url = post.href?.absoluteString,
              let description = post.description,
              let date = post.time else {
            completion(.failure(BookmarksError.malformedBookmark))
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        let dt = dateFormatter.string(from: date)

        let parameters: [String: String] = [
            "url": url,
            "description": description,
            "extended": post.extended,
            "tags": post.tags.joined(separator: " "),
            "dt": dt,
            "replace": replace ? "yes" : "no",
            "shared": post.shared ? "yes" : "no",
            "toread": post.toRead ? "yes" : "no"
        ]
        print(parameters)
        self.fetch(path: .postsAdd, parameters: parameters, completion: completion) { _ in }
    }

    public func postsAll(completion: @escaping (Result<[Post], Error>) -> Void) {
        self.fetch(path: .postsAll, completion: completion) { data in
            return try JSONDecoder().decode([Post].self, from: data)
        }
    }

    public func postsDelete(url: URL, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
        let parameters = [
            "url": url.absoluteString,
        ]
        self.fetch(path: .postsDelete, parameters: parameters, completion: completion) { _ in }
    }

    public func tagsDelete(_ tag: String, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
        let parameters = [
            "tag": tag,
        ]
        self.fetch(path: .tagsDelete, parameters: parameters, completion: completion) { _ in }
    }

    public func tagsRename(_ old: String, to new: String, completion: @escaping (Result<Void, Swift.Error>) -> Void) {
        let parameters = [
            "old": old,
            "new": new,
        ]
        self.fetch(path: .tagsRename, parameters: parameters, completion: completion) { _ in }
    }

    public func apiToken(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        do {
            let url = try "https://\(username):\(password)@api.pinboard.in/v1/user/api_token/".url.settingQueryItems([
                URLQueryItem(name: "format", value: "json"),
            ])
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard let data = data else {
                    guard let error = error else {
                        completion(.failure(PinboardError.inconsistentState(message: "Missing error when processing URL completion")))
                        return
                    }
                    completion(.failure(error))
                    return
                }
                guard let httpStatus = response as? HTTPURLResponse,
                      httpStatus.statusCode == 200 else {
                          completion(.failure(BookmarksError.corrupt))
                          return
                }
                do {
                    let token = try JSONDecoder().decode(Token.self, from: data)
                    completion(.success("\(username):\(token.result)"))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }

}

extension Pinboard {

    func postsUpdate() throws -> Update {
        try AsyncOperation({ self.postsUpdate(completion: $0) }).wait()
    }

    func postsAdd(post: Post, replace: Bool) throws {
        try AsyncOperation({ self.postsAdd(post: post, replace: replace, completion: $0) }).wait()
    }

    func postsAll() throws -> [Post] {
        try AsyncOperation({ self.postsAll(completion: $0) }).wait()
    }

    func postsDelete(url: URL) throws {
        try AsyncOperation({ self.postsDelete(url: url, completion: $0) }).wait()
    }

    func tagsDelete(_ tag: String) throws {
        try AsyncOperation({ self.tagsDelete(tag, completion: $0) }).wait()
    }

    func tagsRename(_ old: String, to new: String) throws {
        try AsyncOperation({ self.tagsRename(old, to: new, completion: $0) }).wait()
    }

}
