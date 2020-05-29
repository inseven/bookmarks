//
//  ImageCache.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 28/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import UIKit

protocol ImageCache {

    func set(identifier: String, image: UIImage, completion: @escaping (Result<Bool, Error>) -> Void)
    func get(identifier: String, completion: @escaping (Result<UIImage, Error>) -> Void)
    func clear(completion: @escaping (Result<Bool, Error>) -> Void)

}

enum ImageCacheError : Error {
    case notFound
}
