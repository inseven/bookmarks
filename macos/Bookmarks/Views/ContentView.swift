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

struct SelectableViewInfo<ID: Hashable> {

    let view: SelectableMarker<ID>.SelectableMarkerView
    let frame: CGRect

    var id: ID { view.id }

    var xRange: Range<CGFloat> {
        Range(uncheckedBounds: (frame.origin.x, frame.origin.x + frame.size.width))
    }

    var yRange: Range<CGFloat> {
        Range(uncheckedBounds: (frame.origin.y, frame.origin.y + frame.size.height))
    }

}

struct LayerView<Element, ID>: NSViewRepresentable where Element: Identifiable & Hashable, ID: Hashable {

    class InjectionHostingView: NSView {

        @Binding var region: CGRect?
        var tracker: SelectionTracker<Element>

        var startPoint : NSPoint!

        required init(region: Binding<CGRect?>, tracker: SelectionTracker<Element>) {
            _region = region
            self.tracker = tracker
            super.init(frame: .zero)
            self.wantsLayer = true
        }

        @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // We flip the coordinate system so we get coordinates that play nicely with SwiftUI.
        override var isFlipped: Bool { true }

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            self.startPoint = self.convert(event.locationInWindow, from: nil)
            region = CGRect(p1: startPoint, p2: startPoint)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {

            // Even though we're below the other views in the view heirarchy, we will still consume touches
            // that should go to the views above us in the ZStack unless explicitly avoid them.
            if self.selectableViews.filter({ $0.frame.contains(point) }).count > 0 {
                return nil
            }

            return self
        }

        override func mouseDragged(with event: NSEvent) {
            let point = self.convert(event.locationInWindow, from: nil)
            updateSelection(start: startPoint, end: point)
            region = CGRect(p1: startPoint, p2: point)
        }

        override func mouseUp(with event: NSEvent) {
            let end = self.convert(event.locationInWindow, from: nil)
            updateSelection(start: startPoint, end: end)
            region = nil
        }

        func updateSelection(start: CGPoint, end: CGPoint) {
            let selection = CGRect(p1: start, p2: end)
            let views = selectableViews.filter { $0.frame.intersects(selection) }
            let ids = views.map { $0.id }
            tracker.select(ids: ids)
        }

        var selectableViews: [SelectableViewInfo<Element.ID>] {
            guard let superview = superview?.superview,
                  let subviews = superview.recursiveSubviews(matching: {
                      type(of: $0) == SelectableMarker<Element.ID>.SelectableMarkerView.self
                  }) as? [SelectableMarker<Element.ID>.SelectableMarkerView] else {
                return []
            }
            return subviews.map { SelectableViewInfo(view: $0, frame: $0.frame(in: self)) }
        }

        override func keyDown(with event: NSEvent) {
            guard let direction = event.moveCommandDirection else {
                super.keyDown(with: event)
                return
            }
            select(direction: direction, event: event)
        }

        func select(direction: MoveCommandDirection, event: NSEvent) {

            let relativeViews = selectableViews

            guard let focusedView = relativeViews.first(where: { $0.id == tracker.cursor?.id }) else {
                _ = tracker.handleDirectionDown()
                return
            }

            // Filter the views by views in the same plane.
            var candidateViews: [SelectableViewInfo<Element.ID>] = []
            switch direction {
            case .up, .down:
                candidateViews = relativeViews.filter { focusedView.xRange.overlaps($0.xRange) }
            case .left, .right:
                candidateViews = relativeViews.filter { focusedView.yRange.overlaps($0.yRange) }
            @unknown default:
                print("unknown direction")
            }

            var sortedViews: [SelectableViewInfo<Element.ID>] = []
            switch direction {
            case .up:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.y < $1.frame.origin.y }).reversed()
            case .down:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.y < $1.frame.origin.y })
            case .left:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.x < $1.frame.origin.x }).reversed()
            case .right:
                sortedViews = candidateViews.sorted(by: { $0.frame.origin.x < $1.frame.origin.x })
            @unknown default:
                print("unknown direction")
            }

            if let index = sortedViews.firstIndex(where: { $0.id == tracker.cursor?.id }) {
                print("selection: current index = \(index)")
                if index < sortedViews.count - 1 {
                    let nextView = sortedViews[index + 1].view
                    print("selection: setting id...")

                    if let item = tracker.items.first(where: { $0.id == nextView.id }) {
                        if event.modifierFlags.contains(.shift) {
                            tracker.handleShiftClick(item: item)
                        } else {
                            tracker.handleClick(item: item)
                        }
                        if let scrollView = self.scrollView {
                            let nextFrame = nextView.frame(in: scrollView)
                            scrollView.contentView.scrollToVisible(nextFrame)
                            print("selection: next selection frame = \(nextFrame)")
                        }

                    }

                }
            } else {
                print("selection: selecting the first view")
                _ = tracker.handleDirectionDown()
            }

        }

    }

    class Coordinator: NSObject {

        var parent: LayerView

        init(_ parent: LayerView) {
            self.parent = parent
        }

    }

    @Binding var region: CGRect?
    var tracker: SelectionTracker<Element>

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> InjectionHostingView {
        return InjectionHostingView(region: $region, tracker: tracker)
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


struct Selectable<Element>: ViewModifier where Element: Identifiable & Hashable {

    var tracker: SelectionTracker<Element>
    var id: Element.ID
    @State var firstResponder: Bool = false
    @State var hasSelectionFocus: Bool = false

    var onSelectionChange: (Bool) -> Void = { _ in }

    func element() -> Element? {
        tracker.items.first(where: { $0.id == id })
    }

    func body(content: Content) -> some View {
        content
            .handleMouse {
                // TODO: This behaviour differs between lists and grids.
                guard let element = element() else {
                    return
                }
                if firstResponder || !tracker.isSelected(item: element) {
                    tracker.handleClick(item: element)
                }
                firstResponder = true
            } doubleClick: {
                // TODO: Double click action.
//                NSWorkspace.shared.open(bookmark.url)
            } shiftClick: {
                guard let element = element() else {
                    return
                }
                tracker.handleShiftClick(item: element)
            } commandClick: {
                guard let element = element() else {
                    return
                }
                tracker.handleCommandClick(item: element)
            }
            .background(SelectableMarker(id: id, hasSelectionFocus: $hasSelectionFocus))
            .onChange(of: hasSelectionFocus, perform: onSelectionChange)
    }

}

extension View {

    public func selectable<Element: Hashable & Identifiable>(tracker: SelectionTracker<Element>, id: Element.ID, onSelectionChange: @escaping (Bool) -> Void = { _ in }) -> some View {
        modifier(Selectable(tracker: tracker, id: id, onSelectionChange: onSelectionChange))
    }

    public func selectionContainer<Element: Hashable & Identifiable>(tracker: SelectionTracker<Element>) -> some View {
        modifier(SelectionContainer(tracker: tracker))
    }

}

struct SelectionContainer<Element>: ViewModifier where Element: Hashable & Identifiable {

    @State var region: CGRect?
    var tracker: SelectionTracker<Element>

    func body(content: Content) -> some View {
        ZStack {
            LayerView<Element, Element.ID>(region: $region, tracker: tracker)
            content
            if let region = region {
                SelectionIndicator(region: region)
            }
        }
    }

}

struct ContentView: View {

    @Environment(\.manager) var manager
    @Environment(\.applicationHasFocus) var applicationHasFocus

    @ObservedObject var selection: BookmarksSelection
    @Binding var section: BookmarksSection?
    @Binding var sheet: ApplicationState?

    @State var underlyingSection: BookmarksSection?
    @StateObject var bookmarksView: BookmarksView
    @StateObject var selectionTracker: SelectionTracker<Bookmark>
    @State var firstResponder: Bool = false
    @StateObject var searchDebouncer = Debouncer<String>(initialValue: "", delay: .seconds(0.2))

    private var subscription: AnyCancellable?

    init(selection: BookmarksSelection, section: Binding<BookmarksSection?>, database: Database, sheet: Binding<ApplicationState?>) {
        self.selection = selection
        _section = section
        let bookmarksView = Deferred(BookmarksView(database: database, query: True().eraseToAnyQuery()))
        let selectionTracker = Deferred(SelectionTracker(items: bookmarksView.get().$bookmarks))
        _bookmarksView = StateObject(wrappedValue: bookmarksView.get())
        _selectionTracker = StateObject(wrappedValue: selectionTracker.get())
        _sheet = sheet
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
                            .modifier(BorderedSelection(selected: selectionTracker.isSelected(item: bookmark), firstResponder: true))
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
                                selection.bookmarks = selectionTracker.selection
                            }
                            .menuType(.context)
                            .onDrag {
                                selectionTracker.handleClick(item: bookmark)
                                return NSItemProvider(object: bookmark.url as NSURL)
                            } preview: {
                                Text(bookmark.title)
                                    .lineLimit(2)
                                    .padding(8)
                                    .background(.white)
                                    .cornerRadius(8)
                            }
                            .selectable(tracker: selectionTracker, id: bookmark.id)  // TODO: Can I inject the ID?
                            // TODO: Put the context menu after this and make it custom to this class?
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
