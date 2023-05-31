// Copyright (c) 2020-2023 InSeven Limited
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

import SafariServices
import SwiftUI

import BookmarksCore

struct ContentView: View {

    @EnvironmentObject var extensionModel: SafariExtensionModel

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            if let pinboard = extensionModel.pinboard {
                ForEach(Array(extensionModel.tabs)) { tab in
                    ItemView(store: extensionModel, pinboard: pinboard, tab: tab)
                    Divider()
                }
            } else {
                Text("Unauthorized")
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack {
                    Text("Bookmarks")
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        openURL(URL(string: "https://pinboard.in")!)
                        SafariExtensionViewController.shared.dismissPopover()
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .buttonStyle(.plain)
                    .help("Open Pinboard")
                }
                .padding()
                Divider()
            }
            .background(.background)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("\(extensionModel.tabs.count) Tabs")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .background(.background)
        }
        .frame(width: 600, height: 800)
        .onAppear {
            extensionModel.refresh()
        }
    }

}
