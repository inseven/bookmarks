// Copyright (c) 2020-2024 Jason Morley
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

#if os(macOS)

import Foundation
import SafariServices
import SwiftUI

public extension SFSafariWindow {

    func urls() async -> [URL] {
        var urls: [URL] = []
        print("Getting tabs...")
        let tabs = await allTabs()
        print("Got tabs")
        for tab in tabs {
            guard let activePage = await tab.activePage(),
                  let properties = await activePage.properties(),
                  let url = properties.url else {
                print("Failed to get properties")
                continue
            }
            urls.append(url)
        }
        return urls
    }

    func tabs() async -> [Tab] {
        var tabs: [Tab] = []
        for tab in await allTabs() {
            guard let activePage = await tab.activePage(),
                  let properties = await activePage.properties(),
                  let image = await activePage.screenshotOfVisibleArea(),
                  let url = properties.url else {
                print("Failed to get properties")
                continue
            }
            tabs.append(Tab(url: url,
                            title: properties.title ?? url.absoluteString,
                            image: Image(nsImage: image)))
        }
        return tabs
    }

    func close(_ url: URL) async {
        for tab in await allTabs() {
            guard let properties = await tab.activePage()?.properties(),
                  properties.url == url
            else {
                continue
            }
            tab.close()
        }
    }

    func activate(_ url: URL) async {
        for tab in await allTabs() {
            guard let properties = await tab.activePage()?.properties(),
                  properties.url == url
            else {
                continue
            }
            await tab.activate()
        }
    }

}

#endif
