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

import Diligence
import Interact

public struct Legal {

    public static let contents = Contents(repository: "inseven/bookmarks",
                                          copyright: "Copyright © 2020-2025 Jason Morley") {

        let subject = "Bookmarks Support (\(Bundle.main.version ?? "Unknown Version"))"

        Action("Website", url: URL(string: "https://bookmarks.jbmorley.co.uk")!)
        Action("Privacy Policy", url: URL(string: "https://bookmarks.jbmorley.co.uk/privacy-policy")!)
        Action("GitHub", url: URL(string: "https://github.com/inseven/bookmarks")!)
        Action("Support", url: URL(address: "support@jbmorley.co.uk", subject: subject)!)

    } acknowledgements: {
        Acknowledgements("Developers") {
            Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk"))
        }
        Acknowledgements("Thanks") {
            Credit("Blake Merryman")
            Credit("Joanne Wong")
            Credit("Lukas Fittl")
            Credit("Pavlos Vinieratos")
            Credit("Sara Frederixon")
            Credit("Sarah Barbour")
            Credit("Terrence Talbot")
        }
    } licenses: {
        License("Bookmarks", author: "Jason Morley", filename: "bookmarks-license", bundle: .module)
        License("HashRainbow", author: "Sarah Barbour", filename: "hashrainbow-license", bundle: .module)
        License(Interact.Package.name, author: Interact.Package.author, url: Interact.Package.licenseURL)
        License("SelectableCollectionView", author: "Jason Morley", filename: "selectablecollectionview-license", bundle: .module)
        License("Swift Algorithm Club", author: "Matthijs Hollemans and Contributors", filename: "swift-algorithm-club-license", bundle: .module)
        License("SwiftSoup", author: "Nabil Chatbi", filename: "swiftsoup-license", bundle: .module)
        License("SQLite.swift", author: "Stephen Celis", filename: "sqlite-swift-license", bundle: .module)
        License("TFHpple", author: "Topfunky Corporation", filename: "tfhpple-license", bundle: .module)
        License("WrappingHStack", author: "Konstantin Semianov", filename: "wrappinghstack-license", bundle: .module)
    }

}
