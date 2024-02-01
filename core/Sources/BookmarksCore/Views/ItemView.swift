// Copyright (c) 2020-2024 InSeven Limited
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

import SwiftUI

import WrappingHStack

public struct ItemView: View {

    var extensionModel: SafariExtensionModel

    @StateObject var model: ItemViewModel
    @State var title: String? = nil

    public init(extensionModel: SafariExtensionModel, pinboard: Pinboard, tab: Tab) {
        self.extensionModel = extensionModel
        _model = StateObject(wrappedValue: ItemViewModel(extensionModel: extensionModel, pinboard: pinboard, tab: tab))
    }

    struct LayoutMetrics {
        static let scale = 0.25
        static let thumbnailCornerRadius = 8.0
    }

    public var body: some View {
        HStack(alignment: .top) {
            Button {
                model.activate()
            } label: {
                model.tab.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)
                    .cornerRadius(LayoutMetrics.thumbnailCornerRadius)
                    .shadow(radius: 4)
                    .padding(8)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading) {
                TextField("Title", text: $model.title, axis: .vertical)
                    .lineLimit(5)
                    .textFieldStyle(.plain)
                Divider()

                TokenView("Add tags...", tokens: $model.tokens) { candidate, existing, count in
                    return extensionModel.suggestions(prefix: candidate, existing: existing, count: count)
                }
                .padding(.horizontal, 6)

                if let date = model.post?.time {
                    HStack {
                        Text("Last Saved")
                        Text(date, style: .date)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        model.close()
                    } label: {
                        Text("Close")
                    }
                    Button {
                        model.save()
                    } label: {
                        Text("Save and Close")
                    }
                }
                Spacer()
            }
            .overlay {
                if model.isLoading {
                    HStack(alignment: .center) {
                        Spacer()
                        VStack(alignment: .center) {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(.background)
                }
            }
        }
        .runs(model)
    }

}

#endif
