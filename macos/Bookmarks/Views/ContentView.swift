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

}

struct RelativeView {

    let view: SelectableMarker.SelectableMarkerView
    let frame: CGRect

    var xRange: Range<CGFloat> {
        Range(uncheckedBounds: (frame.origin.x, frame.origin.x + frame.size.width))
    }

    var yRange: Range<CGFloat> {
        Range(uncheckedBounds: (frame.origin.y, frame.origin.y + frame.size.height))
    }


}

struct InjectionView <Content: View>: NSViewRepresentable {

    class InjectionHostingView: NSHostingView <Content> {

        required init(rootView: Content) {
            super.init(rootView: rootView)
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

        // TODO: This view could store the known selection?

        func select(direction: MoveCommandDirection) {
            // TODO: The views should probably not descend into other selectable regions to avoid overlap?
            // TODO: Do I need some sort of proxy for the focusableSection?
            guard let views = subviews(matching: { type(of: $0) == SelectableMarker.SelectableMarkerView.self }) as? [SelectableMarker.SelectableMarkerView] else {
                print("no selectable views")
                return
            }

            print(direction)

            let relativeViews = views.map { RelativeView(view: $0, frame: convert($0.frame, from: $0)) }

            guard let focusedView = relativeViews.first(where: { $0.view.hasSelectionFocus.wrappedValue }) else {
                views.first?.focus()
                return
            }

            // Filter the views by views in the same plane.
            var candidateViews: [RelativeView] = []
            switch direction {
            case .up, .down:
                candidateViews = relativeViews.filter { focusedView.xRange.overlaps($0.xRange) }
            case .left, .right:
                candidateViews = relativeViews.filter { focusedView.yRange.overlaps($0.yRange) }
            @unknown default:
                print("unknown direction")
            }

            var sortedViews: [RelativeView] = []
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

            // Print the frames.
            for view in sortedViews {
                print("frame = \(view.frame)")
            }

            if let index = sortedViews.firstIndex(where: { $0.view.hasSelectionFocus.wrappedValue }) {
                print("index = \(index)")
                if index < sortedViews.count - 1 {
                    sortedViews[index].view.unfocus()
                    sortedViews[index + 1].view.focus()
                }
            } else {
                sortedViews.first?.view.focus()
            }


        }

    }

    class Coordinator: NSObject {

        var parent: InjectionView

        init(_ parent: InjectionView) {
            self.parent = parent
        }

    }

    var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> InjectionHostingView {
        return InjectionHostingView(rootView: content())
    }

    func updateNSView(_ view: InjectionHostingView, context: NSViewRepresentableContext<InjectionView>) {
    }

}

struct LayerView: NSViewRepresentable {

    class InjectionHostingView: NSView {

        required init() {
            super.init(frame: .zero)
            self.wantsLayer = true
            self.layer?.backgroundColor = CGColor(red: 1, green: 0, blue: 1, alpha: 0.2)
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

        // TODO: This view could store the known selection?

        func select(direction: MoveCommandDirection) {
            // TODO: The views should probably not descend into other selectable regions to avoid overlap?
            // TODO: Do I need some sort of proxy for the focusableSection?

            guard let superview = superview?.superview else {
                return
            }

            guard let views = superview.subviews(matching: { type(of: $0) == SelectableMarker.SelectableMarkerView.self }) as? [SelectableMarker.SelectableMarkerView] else {
                print("no selectable views")
                return
            }

            print(direction)

            let relativeViews = views.map { RelativeView(view: $0, frame: convert($0.frame, from: $0)) }

            guard let focusedView = relativeViews.first(where: { $0.view.hasSelectionFocus.wrappedValue }) else {
                views.first?.focus()
                return
            }

            // Filter the views by views in the same plane.
            var candidateViews: [RelativeView] = []
            switch direction {
            case .up, .down:
                candidateViews = relativeViews.filter { focusedView.xRange.overlaps($0.xRange) }
            case .left, .right:
                candidateViews = relativeViews.filter { focusedView.yRange.overlaps($0.yRange) }
            @unknown default:
                print("unknown direction")
            }

            var sortedViews: [RelativeView] = []
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

            // Print the frames.
            for view in sortedViews {
                print("frame = \(view.frame)")
            }

            if let index = sortedViews.firstIndex(where: { $0.view.hasSelectionFocus.wrappedValue }) {
                print("index = \(index)")
                if index < sortedViews.count - 1 {
                    sortedViews[index].view.unfocus()
                    sortedViews[index + 1].view.focus()
                }
            } else {
                sortedViews.first?.view.focus()
            }


        }

    }

    class Coordinator: NSObject {

        var parent: LayerView

        init(_ parent: LayerView) {
            self.parent = parent
        }

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> InjectionHostingView {
        return InjectionHostingView()
    }

    func updateNSView(_ view: InjectionHostingView, context: NSViewRepresentableContext<LayerView>) {
    }

}

struct SelectableMarker: NSViewRepresentable {

    @Binding var hasSelectionFocus: Bool

    class SelectableMarkerView: NSView {

        let hasSelectionFocus: Binding<Bool>

        init(hasSelectionFocus: Binding<Bool>) {
            self.hasSelectionFocus = hasSelectionFocus
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func focus() {
            hasSelectionFocus.wrappedValue = true
        }

        func unfocus() {
            hasSelectionFocus.wrappedValue = false
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
        return SelectableMarkerView(hasSelectionFocus: $hasSelectionFocus)
    }

    func updateNSView(_ view: SelectableMarkerView, context: NSViewRepresentableContext<SelectableMarker>) {
    }

}


struct Selectable: ViewModifier {

    @State var hasSelectionFocus: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(SelectableMarker(hasSelectionFocus: $hasSelectionFocus))
            .border(hasSelectionFocus ? .red : .secondary, width: 10)
    }

}

extension View {

    public func selectable() -> some View {
        modifier(Selectable())
    }

}


struct ExampleView: View {

    var body: some View {
        InjectionView {
            HStack {
                VStack {
                    Text("Hello")
                        .selectable()
                    Text("Goodbye")
                        .selectable()
                }
                Text("Random")
                    .selectable()
            }
        }
    }

}

struct ExampleView2: View {

    var body: some View {
        ZStack {
            HStack {
                VStack {
                    Text("Hello")
                        .selectable()
                    Text("Goodbye")
                        .selectable()
                }
                Text("Random")
                    .selectable()
            }
            LayerView()
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
                    }
                }
                .padding()
            }
            .acceptsFirstResponder(isFirstResponder: $firstResponder)
            .handleMouse {
                firstResponder = true
                selectionTracker.clear()
            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(bookmarksView.state == .loading ? LoadingView() : nil)
            .overlay(ExampleView2())
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
