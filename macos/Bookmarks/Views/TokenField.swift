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

struct TokenizingCharacterSetKey: EnvironmentKey {
    static var defaultValue: CharacterSet = NSTokenField.defaultTokenizingCharacterSet
}

extension EnvironmentValues {
    var tokenizingCharacterSet: CharacterSet {
        get { self[TokenizingCharacterSetKey.self] }
        set { self[TokenizingCharacterSetKey.self] = newValue }
    }
}

struct WrapsKey: EnvironmentKey {
    static var defaultValue: Bool = true
}

extension EnvironmentValues {
    var wraps: Bool {
        get { self[WrapsKey.self] }
        set { self[WrapsKey.self] = newValue }
    }
}

extension View {

    func tokenizingCharacterSet(_ tokenizingCharacterSet: CharacterSet) -> some View {
        environment(\.tokenizingCharacterSet, tokenizingCharacterSet)
    }

    func wraps(_ wraps: Bool) -> some View {
        environment(\.wraps, wraps)
    }

}

public typealias TokenStyle = NSTokenField.TokenStyle

public class TokenFieldWithMenuCallback: NSTokenField {

    var menuDelegate: TokenFieldWithMenuCallbackDelegate?

    @objc func callback(_ menuItem: NSMenuItem) {
        menuDelegate?.tokenField(self, didClickMenuItem: menuItem)
    }

    // https://stackoverflow.com/questions/17147366/auto-resizing-nstokenfield-with-constraint-based-layout
    public override var intrinsicContentSize: NSSize {
        var frame = self.frame
        frame.size.height = CGFloat.greatestFiniteMagnitude;
        let height = self.cell?.cellSize(forBounds: frame).height ?? 0
        return NSMakeSize(200, height);
    }

}

protocol TokenFieldWithMenuCallbackDelegate {
    func tokenField(_ tokenField: TokenFieldWithMenuCallback, didClickMenuItem menuItem: NSMenuItem)
}

extension TokenStyle: CustomStringConvertible {

    public var description: String {
        switch self {
        case .default:
            return ".default"
        case .none:
            return ".none"
        case .rounded:
            return ".rounded"
        case .squared:
            return ".squared"
        case .plainSquared:
            return ".plainSquared"
        @unknown default:
            return "unknown"
        }
    }

}

public struct TokenField<T>: NSViewRepresentable {

    public typealias Token = Bookmarks.Token<T>  // TODO: Messy

    public class Coordinator: NSObject, NSTokenFieldDelegate, TokenFieldWithMenuCallbackDelegate {

        var parent: TokenField

        init(_ parent: TokenField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ notification: Notification) {
            guard let tokenField = notification.object as? NSTokenField else {
                print("unexpected control in update notification")
                return
            }
            print(tokenField.stringValue)

            var tokens: [Token] = []
            for token in tokenField.objectValue as? [Any] ?? [] {
                if let token = token as? Token {
                    print("token (token) = \(token), \(token.tokenStyle), \(token.isPartial)")
                    tokens.append(token)
                } else if let string = token as? String,
                          let token = parent.token(string, true)?.isPartial(true) {
                    print("token (string) = \(token), \(token.tokenStyle), \(token.isPartial)")
                    tokens.append(token)
                }
            }
            parent.tokens = tokens
        }

        fileprivate func token(for representedObject: Any) -> Token? { representedObject as? Token }

        func tokenField(_ tokenField: TokenFieldWithMenuCallback, didClickMenuItem menuItem: NSMenuItem) {
            guard let callback = menuItem.representedObject as? TokenMenuItem<T>.Callback else {
                print("not a menu item callback")
                return
            }
            callback()
        }

        public func tokenField(_ tokenField: NSTokenField,
                               displayStringForRepresentedObject representedObject: Any) -> String? {
            token(for: representedObject)?.displayString
        }

        public func tokenField(_ tokenField: NSTokenField,
                               editingStringForRepresentedObject representedObject: Any) -> String? {
            token(for: representedObject)?.title
        }

        public func tokenField(_ tokenField: NSTokenField,
                               hasMenuForRepresentedObject representedObject: Any) -> Bool {
            token(for: representedObject)?.menu != nil
        }

        public func tokenField(_ tokenField: NSTokenField,
                               menuForRepresentedObject representedObject: Any) -> NSMenu? {
            guard let token = token(for: representedObject) else {
                return nil
            }
            return token.menu?.nsMenu(selector: #selector(TokenFieldWithMenuCallback.callback), token: token)
        }

        public func tokenField(_ tokenField: NSTokenField,
                               styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
            guard let token = token(for: representedObject) else {
                return .default
            }
            return token.tokenStyle
        }

        public func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
            guard let tokens = tokens as? [String] else {
                return []
            }
            return tokens.compactMap {
                return parent.token($0, false)
            }
        }

        // Must return strings.
        public func tokenField(_ tokenField: NSTokenField,
                               completionsForSubstring substring: String,
                               indexOfToken tokenIndex: Int,
                               indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
            parent.completions(substring)
        }

    }

    @Environment(\.font) var font
    @Environment(\.lineLimit) var lineLimit
    @Environment(\.tokenizingCharacterSet) var tokenizingCharacterSet
    @Environment(\.wraps) var wraps

    @Binding var tokens: [Token]

    var title: String
    var token: (String, _ editing: Bool) -> Token?
    var completions: (String) -> [String]

    public init(_ title: String,
                tokens: Binding<[Token]>,
                token: @escaping (String, _ editing: Bool) -> Token?,
                completions: @escaping (_ string: String) -> [String]) {
        self.title = title
        _tokens = tokens
        self.token = token
        self.completions = completions
    }

    public func makeNSView(context: Context) -> TokenFieldWithMenuCallback {
        return TokenFieldWithMenuCallback(frame: .zero)
    }

    public func updateNSView(_ tokenField: TokenFieldWithMenuCallback, context: Context) {
        tokenField.placeholderString = self.title
        tokenField.cell?.wraps = wraps
        tokenField.font = NSFont.preferredFont(forFont: font)
        tokenField.maximumNumberOfLines = lineLimit ?? 0
        tokenField.tokenizingCharacterSet = tokenizingCharacterSet
        tokenField.delegate = context.coordinator
        tokenField.menuDelegate = context.coordinator

        let objectValue: [Any] = tokens.map { token -> Any in
            if token.isPartial {
                return token.title as NSString
            } else {
                return token
            }
        }

        if let currentObjectValue = tokenField.objectValue as? NSArray,
           !currentObjectValue.isEqual(to: objectValue) {
            tokenField.objectValue = objectValue
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

}

public class Token<T>: Identifiable, Equatable {

    public static func == (lhs: Token, rhs: Token) -> Bool {
        lhs.id == rhs.id
    }

    public var id = UUID()

    let title: String
    let displayString: String
    let tokenStyle: TokenStyle
    let menu: TokenMenu<T>?
    let isPartial: Bool
    let associatedValue: T?

    fileprivate init(title: String,
                     displayString: String,
                     tokenStyle: TokenStyle,
                     menu: TokenMenu<T>?,
                     isPartial: Bool,
                     associatedValue: T?) {
        self.title = title
        self.displayString = displayString
        self.tokenStyle = tokenStyle
        self.menu = menu
        self.isPartial = isPartial
        self.associatedValue = associatedValue
    }

    convenience init(_ title: String) {
        self.init(title: title,
                  displayString: title,
                  tokenStyle: .default,
                  menu: nil,
                  isPartial: false,
                  associatedValue: nil)
    }

    public func tokenStyle(_ tokenStyle: TokenStyle) -> Token {
        Token(title: title,
              displayString: displayString,
              tokenStyle: tokenStyle,
              menu: menu,
              isPartial: isPartial,
              associatedValue: associatedValue)
    }

    public func displayString(_ displayString: String) -> Token {
        Token(title: title,
              displayString: displayString,
              tokenStyle: tokenStyle,
              menu: menu,
              isPartial: isPartial,
              associatedValue: associatedValue)
    }

    public func menu(_ menu: TokenMenu<T>) -> Token {
        Token(title: title,
              displayString: displayString,
              tokenStyle: tokenStyle,
              menu: menu,
              isPartial: isPartial,
              associatedValue: associatedValue)
    }

    public func menu(@MenuBuilder<T> _ content: () -> [TokenMenuItem<T>]) -> Token {
        menu(TokenMenu<T>(content))
    }

    func isPartial(_ isPartial: Bool) -> Token {
        Token(title: title,
              displayString: displayString,
              tokenStyle: tokenStyle,
              menu: menu,
              isPartial: isPartial,
              associatedValue: associatedValue)
    }

    func associatedValue(_ associatedValue: T?) -> Token {
        Token(title: title,
              displayString: displayString,
              tokenStyle: tokenStyle,
              menu: menu,
              isPartial: isPartial,
              associatedValue: associatedValue)
    }

}

public struct TokenMenuItem<T> {

    typealias Callback = () -> Void

    var title: String
    var perform: (Token<T>) -> Void

    func nsMenuItem(selector: Selector, token: Token<T>) -> NSMenuItem {
        let nsItem = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        let callback: Callback = {
            perform(token)
        }
        nsItem.representedObject = callback
        return nsItem
    }

    init(_ title: String, perform: @escaping (_ token: Token<T>) -> Void) {
        self.title = title
        self.perform = perform
    }

}

@resultBuilder struct MenuBuilder<T> {

    static func buildBlock() -> [TokenMenuItem<T>] { [] }

}


extension MenuBuilder {

    static func buildBlock(_ settings: TokenMenuItem<T>...) -> [TokenMenuItem<T>] {
        settings
    }

}

public class TokenMenu<T>: NSObject {

    var items: [TokenMenuItem<T>]

    public init(@MenuBuilder<T> _ content: () -> [TokenMenuItem<T>]) {
        items = content()
    }

    func nsMenu(selector: Selector, token: Token<T>) -> NSMenu {
        let menu = NSMenu()
        for item in items {
            let nsItem = item.nsMenuItem(selector: selector, token: token)
            menu.addItem(nsItem)
        }
        return menu
    }

}
