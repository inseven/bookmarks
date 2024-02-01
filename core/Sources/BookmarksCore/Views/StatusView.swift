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

import SwiftUI

public struct StatusView: View {

    @EnvironmentObject var applicationModel: ApplicationModel

    public init() {

    }

    public var body: some View {
        VStack {
            switch applicationModel.progress {
            case .idle:
                Text("Never updated")
            case .active:
                Text("Updating...")
            case .value(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
            case .done(let date):
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text("Updated \(date.formatted(.relative(presentation: .named)))")
                }
            case .failure(let error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
            }
        }
        .font(.footnote)
    }

}
