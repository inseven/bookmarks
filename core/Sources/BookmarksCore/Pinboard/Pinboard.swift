// Copyright (c) 2020-2025 Jason Morley
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

    private enum Path: String {
        case postsUpdate = "posts/update"
        case postsAdd = "posts/add"
        case postsAll = "posts/all"
        case postsDelete = "posts/delete"
        case postsGet = "posts/get"
        case tagsDelete = "tags/delete"
        case tagsGet = "tags/get"
        case tagsRename = "tags/rename"
    }

    private let baseUrl = URL(string: "https://api.pinboard.in/v1/")!
    private let token: String

    public init(token: String) {
        self.token = token
    }

    private func endpoint(for path: Path) -> URL {
        return baseUrl
            .appendingPathComponent(path.rawValue)
            .appending(queryItems: [
                URLQueryItem(name: "auth_token", value: token),
                URLQueryItem(name: "format", value: "json")
            ])
    }

    private func serviceUrl(_ path: Path, parameters: [String:String] = [:]) throws -> URL {
        return endpoint(for: path)
            .appending(queryItems: parameters.map { URLQueryItem(name: $0, value: $1) })
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw BookmarksError.inconsistentState
        }
        guard 200 ..< 300 ~= response.statusCode else {
            guard let code = HTTPStatus(rawValue: response.statusCode) else {
                throw BookmarksError.unknownResponse
            }
            throw BookmarksError.httpError(code)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(T.self, from: data)
        return result
    }

    // TODO: Replace this.
    private func fetch<T>(path: Path,
                          parameters: [String: String] = [:],
                          completion: @escaping (Swift.Result<T, Error>) -> Void,
                          transform: @escaping (Data) throws -> T) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        do {
            let url = try serviceUrl(path, parameters: parameters)
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, let response = response as? HTTPURLResponse else {
                    guard let error = error else {
                        completion(.failure(BookmarksError.inconsistentState))
                        return
                    }
                    completion(.failure(error))
                    return
                }
                guard 200 ..< 300 ~= response.statusCode else {
                    guard let code = HTTPStatus(rawValue: response.statusCode) else {
                        completion(.failure(BookmarksError.unknownResponse))
                        return
                    }
                    completion(.failure(BookmarksError.httpError(code)))
                    return
                }
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

    private func postsUpdate(completion: @escaping (Swift.Result<Update, Error>) -> Void) {
        self.fetch(path: .postsUpdate, completion: completion) { data in
            try JSONDecoder().decode(Update.self, from: data)
        }
    }

    public func postsUpdate() async throws -> Update {
        try await withCheckedThrowingContinuation { completion in
            self.postsUpdate { result in
                completion.resume(with: result)
            }
        }
    }

    // TODO: This is a duplciate?
    // TODO: Post _MUST_ have a description?
    public func postsAdd(_ post: Post) async throws -> Result {
        guard let url = post.href?.absoluteString else {
            throw BookmarksError.malformedBookmark
        }
        let dateFormatter = ISO8601DateFormatter()
        let dt = dateFormatter.string(from: post.time ?? Date())
        let requestURL = endpoint(for: .postsAdd)
            .appending(queryItems: [
                URLQueryItem(name: "url", value: url),
                URLQueryItem(name: "description", value: post.description),
                URLQueryItem(name: "extended", value: post.extended),
                URLQueryItem(name: "tags", value: post.tags.joined(separator: " ")),
                URLQueryItem(name: "dt", value: dt),
                URLQueryItem(name: "shared", value: post.shared ? "yes" : "no"),
                URLQueryItem(name: "toread", value: post.toRead ? "yes" : "no"),
            ])
        let result: Result = try await fetch(url: requestURL)
        if result.resultCode != "done" {
            throw BookmarksError.inconsistentState
        }
        return result
    }

    // TODO: Replace this.
    private func postsAdd(post: Post, replace: Bool, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        guard let url = post.href?.absoluteString,
              let date = post.time else {
            completion(.failure(BookmarksError.malformedBookmark))
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        let dt = dateFormatter.string(from: date)

        let parameters: [String: String] = [
            "url": url,
            "description": post.description,
            "extended": post.extended,
            "tags": post.tags.joined(separator: " "),
            "dt": dt,
            "replace": replace ? "yes" : "no",
            "shared": post.shared ? "yes" : "no",
            "toread": post.toRead ? "yes" : "no"
        ]
        self.fetch(path: .postsAdd, parameters: parameters, completion: completion) { _ in }
    }

    public func postsAdd(post: Post, replace: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.postsAdd(post: post, replace: replace) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func postsAll(completion: @escaping (Swift.Result<[Post], Error>) -> Void) {
        self.fetch(path: .postsAll, completion: completion) { data in
            return try JSONDecoder().decode([Post].self, from: data)
        }
    }

    public func postsAll() async throws -> [Post] {
        try await withCheckedThrowingContinuation { continuation in
            self.postsAll { result in
                continuation.resume(with: result)
            }
        }
    }

    private func postsDelete(url: URL, completion: @escaping (Swift.Result<Void, Swift.Error>) -> Void) {
        let parameters = [
            "url": url.absoluteString,
        ]
        self.fetch(path: .postsDelete, parameters: parameters, completion: completion) { _ in }
    }

    public func postsDelete(url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.postsDelete(url: url) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func postsGet(url: URL) async throws -> Posts {
        let requestURL = endpoint(for: .postsGet)
            .appending(queryItems: [
                URLQueryItem(name: "url", value: url.absoluteString)
            ])
        return try await fetch(url: requestURL)
    }

    private func tagsDelete(_ tag: String, completion: @escaping (Swift.Result<Void, Swift.Error>) -> Void) {
        let parameters = [
            "tag": tag,
        ]
        self.fetch(path: .tagsDelete, parameters: parameters, completion: completion) { _ in }
    }

    public func tagsDelete(_ tag: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.tagsDelete(tag) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func tagsGet() async throws -> [String:Int] {
        let (data, _) = try await URLSession.shared.data(from: endpoint(for: .tagsGet))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode([String:Int].self, from: data)
        return result
    }

    private func tagsRename(_ old: String,
                           to new: String,
                           completion: @escaping (Swift.Result<Void, Swift.Error>) -> Void) {
        let parameters = [
            "old": old,
            "new": new,
        ]
        self.fetch(path: .tagsRename, parameters: parameters, completion: completion) { _ in }
    }

    public func tagsRename(_ old: String, to new: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            tagsRename(old, to: new) { result in
                continuation.resume(with: result)
            }
        }
    }

    public static func apiToken(username: String,
                                password: String,
                                completion: @escaping (Swift.Result<String, Error>) -> Void) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        do {
            let url = try "https://api.pinboard.in/v1/user/api_token/".url.settingQueryItems([
                URLQueryItem(name: "format", value: "json"),
            ])

            let loginString = "\(username):\(password)"
            guard let loginData = loginString.data(using: String.Encoding.utf8) else {
                return
            }
            let base64LoginString = loginData.base64EncodedString()

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data else {
                    guard let error = error else {
                        completion(.failure(BookmarksError.inconsistentState))
                        return
                    }
                    completion(.failure(error))
                    return
                }
                // TODO: Handle HTTP error codes in the Pinboard API responses #135
                 //       https://github.com/inseven/bookmarks/issues/135
                guard let httpStatus = response as? HTTPURLResponse,
                      httpStatus.statusCode == 200 else {
                          let response = String(data: data, encoding: .utf8)
                          print("HTTP call failed with message '\(response ?? "")'")
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
