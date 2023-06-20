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

import SwiftUI

public struct InfoContentView: View {

    @StateObject var model: InfoContentViewModel

    public init(applicationModel: ApplicationModel, id: String) {
        _model = StateObject(wrappedValue: InfoContentViewModel(applicationModel: applicationModel, id: id))
    }

    public var body: some View {
        HStack {
            switch model.state {
            case .uninitialized, .loading:
                ProgressView()
                    .controlSize(.small)
            case .ready:
                Form {
                    Section {
                        TextField("Title", text: $model.update.title, axis: .vertical)
                        TextField("Notes", text: $model.update.notes, axis: .vertical)
                            .lineLimit(5...10)
                    }
                    Section {
                        HStack {
                            Toggle("Unread", isOn: $model.update.toRead)
                            Divider()
                            Toggle("Public", isOn: $model.update.shared)
                        }
                    }
                    Section {
                        TokenView("Add tags...", tokens: $model.tags) { candidate, existing, count in
                            model.suggestions(candidate: candidate, existing: existing, count: count)
                        }
                    }
                    Section {
                        Link(destination: model.update.url) {
                            Text(model.update.url.absoluteString)
                                .multilineTextAlignment(.leading)
                        }
                    } header: {
                        
                    } footer: {
                        Text("Created \(model.update.date.formatted())")
                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle(model.update.title)
        .presents($model.error)
        .runs(model)
    }

}
