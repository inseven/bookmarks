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


// https://stackoverflow.com/questions/5752214/are-the-http-status-codes-defined-anywhere-in-the-ios-sdk
public enum HTTPStatus: Int {

    case `continue` = 100
    case switchingProtocols = 101
    case processing = 102
    case ok = 200
    case created = 201
    case accepted = 202
    case nonAuthoritativeInformation = 203
    case noContent = 204
    case resetContent = 205
    case partialContent = 206
    case multiStatus = 207
    case alreadyReported = 208
    case iAmUsed = 226
    case multipleChoices = 300
    case movedPermanently = 301
    case found = 302
    case seeOther = 303
    case notModified = 304
    case useProxy = 305
    case temporaryRedirect = 307
    case permanentRedirect = 308
    case badRequest = 400
    case unauthorized = 401
    case paymentRequired = 402
    case forbidden = 403
    case notFound = 404
    case methodNotAllowed = 405
    case notAcceptable = 406
    case proxyAuthenticationRequired = 407
    case requestTimeout = 408
    case conflict = 409
    case gone = 410
    case lengthRequired = 411
    case preconditionFailed = 412
    case payloadTooLarge = 413
    case requestURITooLong = 414
    case unsupportedMediaType = 415
    case requestedRangeNotSatisfiable = 416
    case expectationFailed = 417
    case iAmATeapot = 418
    case misdirectedRequest = 421
    case unprocessableEntity = 422
    case locked = 423
    case failedDependency = 424
    case upgradeRequired = 426
    case preconditionRequired = 428
    case tooManyRequests = 429
    case requestHeaderFieldsTooLarge = 431
    case connectionClosedWithoutResponse = 444
    case unavailableForLegalReasons = 451
    case clientClosedRequest = 499
    case internalServerError = 500
    case notImplemented = 501
    case badGateway = 502
    case serviceUnavailable = 503
    case gatewayTimeout = 504
    case httpVersionNotSupported = 505
    case variantAlsoNegotiates = 506
    case insufficientStorage = 507
    case loopDetected = 508
    case notExtended = 510
    case networkAuthenticationRequired = 511
    case networkConnectTimeoutError = 599

}

public class Pinboard {

    enum PinboardError: Error {
        case inconsistentState
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
    // TODO: Generics.
    fileprivate func fetch<T>(path: Path,
                              parameters: [String: String] = [:],
                              completion: @escaping (Result<T, Error>) -> Void,
                              transform: @escaping (Data) throws -> T) {
        let completion = DispatchQueue.global().asyncClosure(completion)
        do {
            let url = try serviceUrl(path, parameters: parameters)
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, let response = response as? HTTPURLResponse else {
                    guard let error = error else {
                        completion(.failure(PinboardError.inconsistentState))
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

    public static func apiToken(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
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
                        completion(.failure(PinboardError.inconsistentState))
                        return
                    }
                    completion(.failure(error))
                    return
                }
                // TODO: Process the HTTP error here!
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
