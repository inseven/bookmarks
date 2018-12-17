//
//  Pinboard.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 16/12/2018.
//  Copyright © 2018 InSeven Limited. All rights reserved.
//

import Foundation

// Believe it or not, Pinboard represents booleans as the strings 'yes' and 'no', causing us to play some very silly
// games.
enum Boolean: String, Codable {
    case yes = "yes"
    case no = "no"
}

struct Post: Codable {
    let description: String?
    let extended: String
    let hash: String
    let href: URL?
    let meta: String
    let shared: Bool
    let tags: [String]
    let time: Date?  // TODO: Is there an elegant way to parse this as a date?
    let toRead: Bool

    enum CodingKeys: String, CodingKey {
        case description = "description"
        case extended = "extended"
        case hash = "hash"
        case href = "href"
        case meta = "meta"
        case shared = "shared"
        case tags = "tags"
        case time = "time"
        case toRead = "toread"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Unfortunately, the Pinboard API uses 0 as a placeholder for a missing description, so we need to do a little
        // dance here to keep everything happy.
        do {
            description = try container.decode(String.self, forKey: .description)
        } catch DecodingError.typeMismatch {
            // We double check that we can parse the key as a boolean to ensure the structure is as we expect.
            let _ = try container.decode(Bool.self, forKey: .description)
            description = nil
        }

        extended = try container.decode(String.self, forKey: .extended)
        href = URL(string: try container.decode(String.self, forKey: .href))
        hash = try container.decode(String.self, forKey: .hash)
        meta = try container.decode(String.self, forKey: .meta)
        shared = try container.decode(Boolean.self, forKey: .shared) == .yes ? true : false
        tags = try container.decode(String.self, forKey: .tags).split(separator: " ").map(String.init)
        time = ISO8601DateFormatter.init().date(from: try container.decode(String.self, forKey: .time))
        toRead = try container.decode(Boolean.self, forKey: .toRead) == .yes ? true : false
    }
}

class Pinboard {

    let baseURL = "https://api.pinboard.in/v1/"
    let postsAll = "posts/all"

    let token: String

    enum PinboardError: Error {
        case invalidURL(message: String)
        case invalidResponse(message: String)
        case inconsistentState(message: String)
    }

    public init(token: String) {
        self.token = token
    }

    func fetch(completion: @escaping (Result<[Post]>) -> Void) {
        guard let base = URL(string: baseURL) else {
            DispatchQueue.global(qos: .default).async {
                completion(.failure(PinboardError.invalidURL(message: "Unable to construct parse base URL")))
            }
            return
        }
        let posts = base.appendingPathComponent(postsAll)
        guard var components = URLComponents(string: posts.absoluteString) else {
            DispatchQueue.global(qos: .default).async {
                completion(.failure(PinboardError.invalidURL(message: "Unable to parse URL components")))
            }
            return
        }
        components.queryItems = [
            URLQueryItem(name: "auth_token", value: token),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else {
            DispatchQueue.global(qos: .default).async {
                completion(.failure(PinboardError.invalidURL(message: "Unable to construct URL from components")))
            }
            return
        }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                guard let error = error else {
                    completion(.failure(PinboardError.inconsistentState(message: "Missing error when processing URL completion")))
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
