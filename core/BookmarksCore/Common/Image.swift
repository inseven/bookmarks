//
//  Image.swift
//  BookmarksCore
//
//  Created by Jason Barrie Morley on 07/04/2021.
//

import Foundation

#if os(iOS)

import UIKit

public typealias Image = UIImage

#else

import AppKit

public typealias Image = NSImage

#endif
