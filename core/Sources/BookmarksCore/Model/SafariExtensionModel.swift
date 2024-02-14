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

import SafariServices
import SwiftUI

public class SafariExtensionModel: ObservableObject {

    let settings = Settings()
    let tagsModel: TagsModel

    @Published public var tabs: [Tab] = []

    private static let database: Database = {
        try! Database(path: Database.sharedStoreURL)
    }()

    public var pinboard: Pinboard? {
        guard let apiKey = settings.pinboardApiKey else {
            return nil
        }
        return Pinboard(token: apiKey)
    }

    public init() {
        self.tagsModel = TagsModel(database: Self.database)
        tagsModel.start()
    }

    @MainActor public func suggestions(prefix: String, existing: [String], count: Int) -> [String] {
        return tagsModel.suggestions(candidate: prefix, existing: existing, count: count)
    }

    public func close(_ tab: Tab) {
        Task {
            await SFSafariApplication.activeWindow()?.close(tab.url)
            DispatchQueue.main.async {
                withAnimation {
                    self.tabs.removeAll { $0.id == tab.id }
                }
            }
        }
    }

    public func activate(_ tab: Tab) {
        Task {
            await SFSafariApplication.activeWindow()?.activate(tab.url)
        }

    }

    public func refresh() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.tabs = []

        Task {
            guard let window = await SFSafariApplication.activeWindow() else {
                NSLog("Failed to get active window.")
                return
            }
            let tabs = await window.tabs()
            DispatchQueue.main.async {
                self.tabs = tabs
            }
        }
    }

}

#endif
