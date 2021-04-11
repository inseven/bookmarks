// Copyright (c) 2018-2021 InSeven Limited
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

public struct FrameAutosaveView: NSViewRepresentable {

    public class FrameAutosaveNSView: NSView {

        var name: String

        init(name: String) {
            self.name = name
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override func viewDidMoveToWindow() {
            if let frameDescriptor = UserDefaults.standard.string(forKey: name) {
                window?.setFrame(from: frameDescriptor)
            }
            NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                   object: nil,
                                                   queue: nil) { (notification) in
                guard let frameDescriptor = self.window?.frameDescriptor else {
                    return
                }
                UserDefaults.standard.setValue(frameDescriptor, forKey: self.name)
            }
        }
    }

    public class Coordinator: NSObject {
        var parent: FrameAutosaveView

        init(_ parent: FrameAutosaveView) {
            self.parent = parent
        }

    }

    let name: String

    public init(_ name: String) {
        self.name = name
    }

    public func makeNSView(context: Context) -> FrameAutosaveNSView {
        return FrameAutosaveNSView(name: "name")
    }

    public func updateNSView(_ view: FrameAutosaveNSView, context: Context) {
        view.name = name
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

}

struct FrameAutosave: ViewModifier {

    let name: String

    func body(content: Content) -> some View {
        ZStack {
            content
            FrameAutosaveView(name)
                .frame(maxHeight: 0)
        }
    }
}

extension View {

    func frameAutosaveName(_ name: String) -> some View {
        return self.modifier(FrameAutosave(name: name))
    }

}
