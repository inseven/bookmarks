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

#if os(iOS)

import SwiftUI

import Interact

public struct PhoneEditTagsView: View {

    private enum Field {
        case input
    }

    @ObservedObject var tokenViewModel: TokenViewModel

    @Binding var tags: [String]

    @FocusState private var focus: Field?

    public var body: some View {
        NavigationView {
            List {
                ForEach(tags.sorted()) { tag in
                    HStack {
                        TagView(tag)
                        Spacer()
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if tags.isEmpty {
                    PlaceholderView("No Tags")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 16) {
                        TextField("Add tag...", text: $tokenViewModel.input)
                            .keyboardType(.alphabet)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit {
                                tokenViewModel.commit()
                            }
                            .focused($focus, equals: .input)
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tokenViewModel.suggestions) { suggestion in
                                    Button {
                                        tokenViewModel.acceptSuggestion(suggestion)
                                    } label: {
                                        TagView(suggestion)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background(.thinMaterial)
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .dismissable(.done)
            .defaultFocus($focus, .input)
        }
        .navigationViewStyle(.stack)
    }
    
}

#endif
