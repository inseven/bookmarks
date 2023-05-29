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

#if os(macOS)

import Carbon
import Combine
import SwiftUI
import WebKit

import WrappingHStack

struct PickerTextField: NSViewRepresentable {

    class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {

        var isDeleting = false

        let parent: PickerTextField

        var lastUserInput = ""
        var lastSuggestion = ""

        init(_ parent: PickerTextField) {
            self.parent = parent
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard let event = textView.window?.currentEvent else {
                return false
            }

            if event.keyCode == kVK_Delete {

                isDeleting = true

                // We're only intereseted in delete events when the cursor is at the beginning of the text.
                guard textView.selectedRanges.count == 1,
                      let range = textView.selectedRanges.first as? NSRange,
                      range.location == 0,
                      range.length == 0
                else {
                    return false
                }
                parent.onDelete()
            } else if event.keyCode == kVK_Return || event.keyCode == kVK_Tab {
                parent.onCommit()
            }

            return false
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                print("unexpected control in update notification")
                return
            }

            self.parent.text = textField.stringValue

            guard let textView = textField.currentEditor() as? NSTextView else {
                return
            }

            guard !textField.stringValue.isEmpty,
                  !isDeleting,
                  let suggestion = parent.suggestion(textField.stringValue).first,
                  suggestion.starts(with: textField.stringValue)
            else {
                isDeleting = false
                return
            }
            lastSuggestion = suggestion
            textView.insertCompletion(suggestion,
                                      forPartialWordRange: NSRange(location: 0, length: textField.stringValue.count),
                                      movement: 0,
                                      isFinal: false)
        }

    }

    let prompt: String

    @Binding var text: String

    var onDelete: () -> Void
    var onCommit: () -> Void
    var suggestion: (String) -> [String]

    init(_ prompt: String,
         text: Binding<String>,
         onCommit: @escaping () -> Void,
         onDelete: @escaping () -> Void,
         suggestion: @escaping (String) -> [String]) {
        self.prompt = prompt
        _text = text
        self.onCommit = onCommit
        self.onDelete = onDelete
        self.suggestion = suggestion
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.placeholderString = prompt
        textField.backgroundColor = .clear
        textField.font = NSFont.preferredFont(forTextStyle: .body)
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        if textField.stringValue != text {
            textField.stringValue = text
        }

    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

}

class TokenFieldModel: ObservableObject {

    struct Token: Identifiable {

        let id = UUID()
        let text: String

        init(_ text: String) {
            self.text = text
        }

    }

    @Binding var tokens: [String]

    @Published var items: [Token] = []
    @Published var input: String = ""

    var cancellables: [AnyCancellable] = []

    init(tokens: Binding<[String]>) {
        _tokens = tokens
    }

    func start() {

        $input
            .receive(on: DispatchQueue.main)
            .filter { $0.containsWhitespaceAndNewlines() }
            .sink { [weak self] tags in
                guard let self else { return }
                self.commit()
            }
            .store(in: &cancellables)

        $items
            .receive(on: DispatchQueue.main)
            .map { $0.map { $0.text } }
            .assign(to: \.tokens, on: self)
            .store(in: &cancellables)
    }

    func stop() {
        cancellables = []
    }

    func commit() {
        let tags = input
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        for tag in tags {
            self.items.append(Token(tag))
        }
        input = ""
    }

    func deleteBackwards() {
        guard !items.isEmpty else {
            return
        }
        items.removeLast()
    }

}

public struct TokenView: View {

    let prompt: String

    @Binding var tokens: [String]

    let suggestion: (String) -> [String]

    @StateObject var model: TokenFieldModel

    public init(_ prompt: String,
                tokens: Binding<[String]>,
                suggestion: @escaping (String) -> [String]) {
        self.prompt = prompt
        _tokens = tokens
        self.suggestion = suggestion
        _model = StateObject(wrappedValue: TokenFieldModel(tokens: tokens))
    }

    public var body: some View {
        VStack {
            WrappingHStack(alignment: .leading) {
                ForEach(model.items) { item in
                    TagView(item.text, color: item.text.color())
                }
                PickerTextField(prompt, text: $model.input) {
                    model.commit()
                } onDelete: {
                    model.deleteBackwards()
                } suggestion: { candidate in
                    return suggestion(candidate)
                }
                .frame(maxWidth: 100)
                .padding([.top, .bottom], 4)
            }
        }
        .onAppear {
            model.start()
        }
        .onDisappear {
            model.stop()
        }
        .onChange(of: tokens) { tokens in
            // I find it really hard to believe that this is the idiomatic way of bidirectional binding.
            guard model.items.map({ $0.text }) != tokens else {
                return
            }
            model.items = tokens.map({ TokenFieldModel.Token($0) })
        }
    }

}

#endif
