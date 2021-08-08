// Copyright (c) 2020-2021 InSeven Limited
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

import AppKit
import SwiftUI

import BookmarksCore

struct ApplicationHasFocusKey: EnvironmentKey {
    static var defaultValue: Bool = true
}

extension EnvironmentValues {
    var applicationHasFocus: Bool {
        get { self[ApplicationHasFocusKey.self] }
        set { self[ApplicationHasFocusKey.self] = newValue }
    }
}

struct SelectionColorKey: EnvironmentKey {
    static var defaultValue: Color = Color.selectedContentBackgroundColor
}

extension EnvironmentValues {
    var selectionColor: Color {
        get { self[SelectionColorKey.self] }
        set { self[SelectionColorKey.self] = newValue }
    }
}


@main
struct BookmarksApp: App {

    @Environment(\.manager) var manager: BookmarksManager
    @State var selection: BookmarksSection? = .all
    @State var applicationHasFocus = true

    var body: some Scene {
        WindowGroup {
            NavigationView {
                Sidebar(tagsView: TagsView(database: manager.database), settings: manager.settings, selection: $selection)
                ContentView(sidebarSelection: $selection, database: manager.database)
            }
            .environment(\.applicationHasFocus, applicationHasFocus)
            .environment(\.selectionColor, applicationHasFocus ? Color.selectedContentBackgroundColor : Color.unemphasizedSelectedContentBackgroundColor)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                print("lost focus")
                applicationHasFocus = false
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                print("gained focus")
                applicationHasFocus = true
            }
            .frameAutosaveName("Main Window")
        }
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(after: .newItem) {
                Divider()
                Button("Refresh") {
                    manager.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Go") {
                Button("All Bookmarks") {
                    selection = .all
                }
                .keyboardShortcut("1", modifiers: .command)
                Button("Private") {
                    selection = .shared(false)
                }
                .keyboardShortcut("2", modifiers: .command)
                Button("Public") {
                    selection = .shared(true)
                }
                .keyboardShortcut("3", modifiers: .command)
                Button("Today") {
                    selection = .today
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Unread") {
                    selection = .unread
                }
                .keyboardShortcut("5", modifiers: .command)
                Button("Untagged") {
                    selection = .untagged
                }
                .keyboardShortcut("6", modifiers: .command)
            }
        }
        SwiftUI.Settings {
            SettingsView()
        }
    }
}
