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

import Combine
import SwiftUI

import BookmarksCore
import Interact
import XCTest

extension NSView {

    func subviews(matching matcher: (NSView) -> Bool) -> [NSView] {
        var result: [NSView] = []
        for view in subviews {
            if matcher(view) {
                result.append(view)
            }
            result = result + view.subviews(matching: matcher)
        }
        return result
    }

    var scrollView: NSScrollView? {
        if let scrollView = self as? NSScrollView {
            return scrollView
        }
        return self.superview?.scrollView
    }

    func frame(in view: NSView) -> CGRect {
        view.convert(self.frame, from: self)
    }

}

struct RelativeView<ID: Hashable> {

    let view: SelectableMarker<ID>.SelectableMarkerView
    let frame: CGRect

    var xRange: Range<CGFloat> {
        Range(uncheckedBounds: (frame.origin.x, frame.origin.x + frame.size.width))
    }

    var yRange: Range<CGFloat> {
        Range(uncheckedBounds: (frame.origin.y, frame.origin.y + frame.size.height))
    }

}

struct LayerView<Element, ID>: NSViewRepresentable where Element: Identifiable & Hashable, ID: Hashable {

    class InjectionHostingView: NSView {

        var focus: Binding<Element.ID?>

        required init(focus: Binding<Element.ID?>) {
            self.focus = focus
            super.init(frame: .zero)
            self.wantsLayer = true
            self.layer?.backgroundColor = CGColor(red: 1, green: 0, blue: 1, alpha: 0.01)
        }

        @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            // TODO: Consider passing on the mouse down event?
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let character = event.characters?.first
            switch character {
            case KeyEquivalent.downArrow.character:
                select(direction: .down)
            case KeyEquivalent.upArrow.character:
                select(direction: .up)
            case KeyEquivalent.leftArrow.character:
                select(direction: .left)
            case KeyEquivalent.rightArrow.character:
                select(direction: .right)
            default:
                super.keyDown(with: event)
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            window?.makeFirstResponder(self)
            return nil
        }

        // TODO: This view could store the known selection?

        func select(direction: MoveCommandDirection) {
            // TODO: The views should probably not descend into other selectable regions to avoid overlap?
            // TODO: Do I need some sort of proxy for the focusableSection?

            guard let superview = superview?.superview else {
                return
            }

            guard let views = superview.subviews(matching: { type(of: $0) == SelectableMarker<Element.ID>.SelectableMarkerView.self }) as? [SelectableMarker<Element.ID>.SelectableMarkerView] else {
                print("selection: no selectable views")
                return
            }

            print(direction)

            let relativeViews = views.map { RelativeView(view: $0, frame: $0.frame(in: self)) }

            guard let focusedView = relativeViews.first(where: { $0.view.id == focus.wrappedValue }) else {
                focus.wrappedValue = views.first?.id
                return
            }

            // Filter the views by views in the same plane.
            var candidateViews: [RelativeView<Element.ID>] = []
            switch direction {
            case .up, .down:
                candidateViews = relativeViews.filter { focusedView.xRange.overlaps($0.xRange) }
            case .left, .right:
                candidateViews = relativeViews.filter { focusedView.yRange.overlaps($0.yRange) }
            @unknown default:
                print("unknown direction")
            }

            var sortedViews: [RelativeView<Element.ID>] = []
            switch direction {
            case .up:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.y < $1.frame.origin.y })
            case .down:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.y < $1.frame.origin.y }).reversed()
            case .left:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.x < $1.frame.origin.x }).reversed()
            case .right:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.x < $1.frame.origin.x })
            @unknown default:
                print("unknown direction")
            }

            if let index = sortedViews.firstIndex(where: { $0.view.id == focus.wrappedValue }) {
                print("selection: current index = \(index)")
                if index < sortedViews.count - 1 {
                    let nextView = sortedViews[index + 1].view
                    print("selection: setting id...")
                    focus.wrappedValue = nextView.id
                    if let scrollView = self.scrollView {
                        let nextFrame = nextView.frame(in: scrollView)
                        scrollView.contentView.scrollToVisible(nextFrame)
                        print("selection: next selection frame = \(nextFrame)")
                    }
                }
            } else {
                print("selection: selecting the first view")
                focus.wrappedValue = views.first?.id
            }

        }

    }

    class Coordinator: NSObject {

        var parent: LayerView

        init(_ parent: LayerView) {
            self.parent = parent
        }

    }

    var tracker: SelectionTracker<Element>

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> InjectionHostingView {

        let binding = Binding<Element.ID?>(get: {
            tracker.cursor?.id
        }, set: { id in
            guard let id = id else {
                tracker.clear()
                return
            }
            tracker.handleClick(id: id)
        })
        return InjectionHostingView(focus: binding)
    }

    func updateNSView(_ view: InjectionHostingView, context: NSViewRepresentableContext<LayerView>) {
    }

}

struct SelectableMarker<ID>: NSViewRepresentable where ID: Hashable {

    var id: ID
    @Binding var hasSelectionFocus: Bool

    class SelectableMarkerView: NSView {

        var id: ID
        let hasSelectionFocus: Binding<Bool>

        init(id: ID, hasSelectionFocus: Binding<Bool>) {
            self.id = id
            self.hasSelectionFocus = hasSelectionFocus
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

//        func focus() {
//            hasSelectionFocus.wrappedValue = true
//        }
//
//        func unfocus() {
//            hasSelectionFocus.wrappedValue = false
//        }

    }

    class Coordinator: NSObject {

        var parent: SelectableMarker

        init(_ parent: SelectableMarker) {
            self.parent = parent
        }

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> SelectableMarkerView {
        return SelectableMarkerView(id: id, hasSelectionFocus: $hasSelectionFocus)
    }

    func updateNSView(_ view: SelectableMarkerView, context: NSViewRepresentableContext<SelectableMarker>) {
    }

}


struct Selectable<ID>: ViewModifier where ID: Hashable {

    var id: ID
    @State var hasSelectionFocus: Bool = false

    var onSelectionChange: (Bool) -> Void = { _ in }

    func body(content: Content) -> some View {
        content
            .background(SelectableMarker(id: id, hasSelectionFocus: $hasSelectionFocus))
            .onChange(of: hasSelectionFocus, perform: onSelectionChange)
    }

}

extension View {

    public func selectable<ID: Hashable>(id: ID, onSelectionChange: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(Selectable(id: id, onSelectionChange: onSelectionChange))
    }

    public func selectionContainer<Element: Hashable & Identifiable>(tracker: SelectionTracker<Element>) -> some View {
        modifier(SelectionContainer(tracker: tracker))
    }

}

struct SelectionContainer<Element>: ViewModifier where Element: Hashable & Identifiable {

    var tracker: SelectionTracker<Element>

    func body(content: Content) -> some View {
        ZStack {
            content
            LayerView<Element, Element.ID>(tracker: tracker)
        }
    }

}

struct ContentView: View {

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus

    @ObservedObject var selection: BookmarksSelection
    @Binding var section: BookmarksSection?

    @State var underlyingSection: BookmarksSection?
    @StateObject var bookmarksView: BookmarksView
    @StateObject var selectionTracker: SelectionTracker<Bookmark>
    @State var firstResponder: Bool = false
    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(selection: BookmarksSelection, section: Binding<BookmarksSection?>, database: Database) {
        self.selection = selection
        _section = section
        let bookmarksView = Deferred(BookmarksView(database: database, query: True().eraseToAnyQuery()))
        let selectionTracker = Deferred(SelectionTracker(items: bookmarksView.get().$bookmarks))
        _bookmarksView = StateObject(wrappedValue: bookmarksView.get())
        _selectionTracker = StateObject(wrappedValue: selectionTracker.get())
    }

    var navigationTitle: String {
        let queries = searchDebouncer.debouncedValue.queries
        if (queries.section == .all && queries.count > 1) || queries.count > 1 {
            return "Search: \(searchDebouncer.debouncedValue)"
        }
        guard let title = section?.navigationTitle else {
            return "Unknown"
        }
        return title
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(bookmarksView.bookmarks) { bookmark in
                        BookmarkCell(bookmark: bookmark)
                            .shadow(color: .shadow, radius: 8)
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: bookmark), firstResponder: firstResponder))
                            .help(bookmark.url.absoluteString)
                            .contextMenuFocusable {
                                BookmarkOpenCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkDesctructiveCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkEditCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkShareCommands(selection: selection)
                                    .trailingDivider()
                                BookmarkTagCommands(selection: selection, section: $section)
                                #if DEBUG
                                BookmarkDebugCommands()
                                    .leadingDivider()
                                #endif
                            } onContextMenuChange: { focused in
                                guard focused == true else {
                                    return
                                }
                                firstResponder = true
                                if !selectionTracker.isSelected(item: bookmark) {
                                    selectionTracker.handleClick(item: bookmark)
                                }
                            }
                            .menuType(.context)
                            .onDrag {
                                NSItemProvider(object: bookmark.url as NSURL)
                            }
                            .handleMouse {
                                if firstResponder || !selectionTracker.isSelected(item: bookmark) {
                                    selectionTracker.handleClick(item: bookmark)
                                }
                                firstResponder = true
                            } doubleClick: {
                                NSWorkspace.shared.open(bookmark.url)
                            } shiftClick: {
                                selectionTracker.handleShiftClick(item: bookmark)
                            } commandClick: {
                                selectionTracker.handleCommandClick(item: bookmark)
                            }
                            .selectable(id: bookmark.id)
                    }
                }
                .padding()
                .selectionContainer(tracker: selectionTracker)
            }
//            }
//            .acceptsFirstResponder(isFirstResponder: $firstResponder)
//            .handleMouse {
//                firstResponder = true
//                selectionTracker.clear()
//            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(bookmarksView.state == .loading ? LoadingView() : nil)
//            .overlay(ExampleView2())
        }
        .onAppear {
            bookmarksView.start()
        }
        .onDisappear {
            bookmarksView.stop()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    manager.refresh()
                } label: {
                    SwiftUI.Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ToolbarItem {
                Button {
                    guard selectionTracker.selection.count > 0 else {
                        return
                    }
                    selection.addTags()
                } label: {
                    SwiftUI.Image(systemName: "tag")
                }
                .help("Add Tags")
                .disabled(selection.isEmpty)
            }
            ToolbarItem {
                Button {
                    selection.delete(manager: manager)
                } label: {
                    SwiftUI.Image(systemName: "trash")
                }
                .help("Delete")
                .disabled(selection.isEmpty)
            }

            ToolbarItem {
                SearchField(search: $searchDebouncer.value)
                    .frame(minWidth: 100, idealWidth: 300, maxWidth: .infinity)
            }
        }
        .onReceive(searchDebouncer.$debouncedValue) { search in

            // Get the query corresponding to the current search text.
            let queries = AnyQuery.queries(for: search)

            // Update the selected section if necessary.
            let section = queries.section
            if section != section {
                underlyingSection = section
            }

            // Update the database query.
            bookmarksView.query = AnyQuery.and(queries)

        }
        .onChange(of: section) { section in

            guard underlyingSection != section,
                  let section = section else {
                return
            }

            underlyingSection = section

            selectionTracker.clear()
            bookmarksView.clear()
            let query = section.query
            searchDebouncer.value = query.filter
            bookmarksView.query = query.eraseToAnyQuery()

        }
        .onChange(of: underlyingSection, perform: { underlyingSection in

            guard section != underlyingSection else {
                return
            }

            // Bring the sidebar section in-line with the underlying section.
            section = underlyingSection

        })
        .onChange(of: selectionTracker.selection) { newSelection in
            selection.bookmarks = newSelection
        }
        .navigationTitle(navigationTitle)
    }
}
