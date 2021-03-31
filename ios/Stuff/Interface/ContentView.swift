// Copyright (c) 2020-2021 Jason Barrie Morley
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

enum BookmarksError: Error {
    case resizeFailure
}

struct BookmarkCell: View {

    var item: Item

    @Environment(\.manager) var manager: BookmarksManager
    @State var image: UIImage?
    @State var publisher: AnyCancellable?

    var title: String {
        if !item.title.isEmpty {
            return item.title
        } else if !item.url.lastPathComponent.isEmpty && item.url.lastPathComponent != "/" {
            return item.url.lastPathComponent
        } else if let host = item.url.host {
            return host
        } else {
            return "Unknown"
        }
    }

    var thumbnail: some View {
        ZStack {
            Text(title)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .clipped()
                    .background(Color.white)
                    .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            thumbnail
                .frame(height: 100)
                .clipped()
            VStack(alignment: .leading) {
                Text(title)
                    .lineLimit(1)
                Text(item.url.host ?? "Unknown")
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .onAppear {
            publisher = manager.thumbnailManager.thumbnail(for: item)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { (completion) in
                    if case .failure(let error) = completion {
                        print("Failed to download thumbnail with error \(error)")
                    }
                }, receiveValue: { image in
                    self.image = image
                })
        }
        .onDisappear {
            guard let publisher = publisher else {
                return
            }
            publisher.cancel()
        }
    }

}

extension String: Identifiable {
    public var id: String { self }
}

struct SearchBoxModifier: ViewModifier {

    @Binding var text: String
    @State var hover = false

    func body(content: Content) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            content
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8.0)
        .background(hover ? Color.pink : Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .onHover { hover in
            self.hover = hover
        }
    }

}

struct BookmarksView: View {

    enum SheetType {
        case settings
    }

    @Environment(\.manager) var manager: BookmarksManager
    @ObservedObject var store: Store
    var title: String
    var tag: String?

    @State var sheet: SheetType?
    @State var search = ""

    var items: [Item] {
        store.rawItems.filter {
            (tag == nil || $0.tags.contains(tag!)) &&
            search.isEmpty ||
                $0.title.localizedStandardContains(search) ||
                $0.url.absoluteString.localizedStandardContains(search) ||
                $0.tags.contains(where: { $0.localizedStandardContains(search) } )
        }
    }

    var body: some View {
        VStack {
            HStack {
                TextField("Search", text: $search)
                    .modifier(SearchBoxModifier(text: $search))
                    .padding()
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(items) { item in
                        BookmarkCell(item: item)
                            .onTapGesture {
                                UIApplication.shared.open(item.url)
                            }
                            .contextMenu(ContextMenu(menuItems: {
                                Button("Share") {
                                    print("Share")
                                    print(item.identifier)
                                }
                            }))
                    }
                }
                .padding()
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView(settings: manager.settings)
                }
            }
        }
        .navigationBarTitle(title, displayMode: .inline)
        .navigationBarItems(leading: Button(action: {
            sheet = .settings
        }) {
            Image(systemName: "gearshape")
                .foregroundColor(.accentColor)
        })
    }

}

struct ContentView: View {

    @Environment(\.manager) var manager: BookmarksManager
    @ObservedObject var store: Store
    @State var selected = true
    @State var filter = ""

    var body: some View {
        NavigationView {
            VStack {
                List {
                    NavigationLink(destination: BookmarksView(store: store, title: "All Bookmarks"), isActive: $selected) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.accentColor)
                            Text("All Bookmarks")
                        }
                        }
                    Section(header: Text("Tags")) {
                        ForEach(store.tags.filter { filter.isEmpty || $0.localizedStandardContains(filter) }) { tag in
                            NavigationLink(destination: BookmarksView(store: store, title: tag, tag: tag)) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(.accentColor)
                                    Text(tag)
                                }
                            }
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                TextField("Filter", text: $filter)
                    .modifier(SearchBoxModifier(text: $filter))
                    .padding()
            }
            .navigationBarTitle("Bookmarks")
        }
    }

}

extension BookmarksView.SheetType: Identifiable {
    public var id: Self { self }
}
