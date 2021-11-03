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

import SwiftUI

struct ShareController: UIViewControllerRepresentable {
    
    class Coordinator {
        
        var presentedItems: [Any]?
        
        func isPresentingItems(_ items: [Any]) -> Bool {
            guard let presentedItems = presentedItems else {
                return false
            }
            let nsPresentedItems = presentedItems as NSArray
            let nsItems = items as NSArray
            return nsPresentedItems.isEqual(nsItems)
        }
        
    }
    
    @Binding var items: [Any]?

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
        if let items = items {
            guard !context.coordinator.isPresentingItems(items) else {
                return
            }
            let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                self.items = nil
            }
            if uiViewController.presentedViewController != nil {
                uiViewController.dismiss(animated: true) {
                    uiViewController.present(activityViewController, animated: true)
                }
            } else {
                uiViewController.present(activityViewController, animated: true)
            }
            context.coordinator.presentedItems = items
        } else {
            guard let activityViewController = uiViewController.presentedViewController else {
                return
            }
            activityViewController.dismiss(animated: true)
        }
    }
}

struct Sharing: ViewModifier {
    
    @Binding var items: [Any]?
    
    func body(content: Content) -> some View {
        content
            .background(ShareController(items: $items))
    }
    
}

extension View {
    
    func sharing(items: Binding<[Any]?>) -> some View {
        modifier(Sharing(items: items))
    }
    
}
