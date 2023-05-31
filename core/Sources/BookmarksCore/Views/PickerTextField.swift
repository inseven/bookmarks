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
import SwiftUI

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

#endif
