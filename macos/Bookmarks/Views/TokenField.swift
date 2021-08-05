//
//  TokenField.swift
//  TokenFields
//
//  Created by Jason Barrie Morley on 05/08/2021.
//

import SwiftUI

public typealias TokenStyle = NSTokenField.TokenStyle

public class TokenFieldWithMenuCallback: NSTokenField {

    var menuDelegate: TokenFieldWithMenuCallbackDelegate?

    @objc func callback(_ menuItem: NSMenuItem) {
        menuDelegate?.tokenField(self, didClickMenuItem: menuItem)
    }

    // https://stackoverflow.com/questions/17147366/auto-resizing-nstokenfield-with-constraint-based-layout
    public override var intrinsicContentSize: NSSize {
        var frame = self.frame
//        let width = frame.size.width
        // Make the frame very high, while keeping the width
        frame.size.height = CGFloat.greatestFiniteMagnitude;
        // Calculate new height within the frame with practically infinite height.
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
                          let token = parent.token(string)?.isPartial(true) {
                    print("token (string) = \(token), \(token.tokenStyle), \(token.isPartial)")
                    tokens.append(token)
                }
            }
            parent.tokens = tokens

//            guard let safeTokens = tokenField.objectValue as? [Token] else {
//                print("unexpected token field value")
//                return
//            }
//            parent.tokens = safeTokens
        }

        fileprivate func token(for representedObject: Any) -> Token? { representedObject as? Token }

        func tokenField(_ tokenField: TokenFieldWithMenuCallback, didClickMenuItem menuItem: NSMenuItem) {
            guard let callback = menuItem.representedObject as? MenuItem<T>.Callback else {
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

        // Can return the generic object?
        public func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
            guard let tokens = tokens as? [String] else {
                return []
            }
            return tokens.compactMap {
                print("test token '\($0)'")
                return parent.token($0)
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

    @Binding var tokens: [Token]

    var title: String
    var token: (String) -> Token?
    var completions: (String) -> [String]

    public init(_ title: String,
                tokens: Binding<[Token]>,
                token: @escaping (_ string: String) -> Token?,
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
        tokenField.cell?.wraps = false
        tokenField.font = NSFont.preferredFont(forFont: font)
        tokenField.maximumNumberOfLines = lineLimit ?? 0
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
    let menu: AMenu<T>?
    let isPartial: Bool
    let associatedValue: T?

    fileprivate init(title: String,
                     displayString: String,
                     tokenStyle: TokenStyle,
                     menu: AMenu<T>?,
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

    public func menu(_ menu: AMenu<T>) -> Token {
        Token(title: title,
              displayString: displayString,
              tokenStyle: tokenStyle,
              menu: menu,
              isPartial: isPartial,
              associatedValue: associatedValue)
    }

    public func menu(@MenuBuilder<T> _ content: () -> [MenuItem<T>]) -> Token {
        menu(AMenu<T>(content))
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

public struct MenuItem<T> {

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

    static func buildBlock() -> [MenuItem<T>] { [] }

}


extension MenuBuilder {

    static func buildBlock(_ settings: MenuItem<T>...) -> [MenuItem<T>] {
        settings
    }

}

public class AMenu<T>: NSObject {

    var items: [MenuItem<T>]

    public init(@MenuBuilder<T> _ content: () -> [MenuItem<T>]) {
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
