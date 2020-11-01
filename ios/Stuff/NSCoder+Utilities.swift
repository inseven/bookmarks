//
//  NSCoder+Utilities.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 31/10/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation

extension NSCoder {

    func decodeString(forKey key: String) -> String? {
        return decodeObject(of: NSString.self, forKey: key) as String?
    }

    func decodeUrl(forKey key: String) -> URL? {
        return decodeObject(of: NSURL.self, forKey: key) as URL?
    }

    func decodeDate(forKey key: String) -> Date? {
        return decodeObject(of: NSDate.self, forKey: key) as Date?
    }

}
