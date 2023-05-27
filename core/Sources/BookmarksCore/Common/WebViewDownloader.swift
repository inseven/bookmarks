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

import Combine
import Foundation
import WebKit

enum WebViewDownloaderError: Error {
    case notFound
    case cancelled
}

protocol Downloader {
    func start()
    func cancel()
}

final class WebViewThumbnailSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == SafeImage, SubscriberType.Failure == Error {
    private var subscriber: SubscriberType?
    private var downloader: Downloader

    init(subscriber: SubscriberType, manager: DownloadManager, url: URL) {
        self.subscriber = subscriber
        self.downloader = manager.downloader(for: url) { (result) in
            switch result {
            case .success(let image):
                _ = subscriber.receive(image)
                subscriber.receive(completion: .finished)
            case .failure(let error):
                subscriber.receive(completion: .failure(error))
            }
        }
        manager.schedule(downloader as! WebViewDownloader)
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        subscriber = nil
        downloader.cancel()
    }
}

class WebViewThumbnailPublisher: Publisher {

    typealias Output = SafeImage
    typealias Failure = Error

    let manager: DownloadManager
    let url: URL

    init(manager: DownloadManager, url: URL) {
        self.manager = manager
        self.url = url
    }

    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == WebViewThumbnailPublisher.Failure, S.Input == WebViewThumbnailPublisher.Output {
        let subscription = WebViewThumbnailSubscription(subscriber: subscriber, manager: manager, url: url)
        subscriber.receive(subscription: subscription)
    }
}

class WebViewDownloader: NSObject, WKNavigationDelegate, Downloader {

    enum State {
        case idle
        case running
        case stopped
    }

    var webView: WKWebView! // TODO: Lazy initialization?
    let url: URL
    let completion: ((Result<URL, Error>) -> Void)
    var state: State

    init(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.url = url
        self.completion = completion
        self.state = .idle
        super.init()
    }

    func start() {
        DispatchQueue.main.async {
            precondition(self.state == .idle)
            self.state = .running
            self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
            self.webView.navigationDelegate = self
            self.webView.load(URLRequest(url: self.url))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard case .running = self.state else {
            return
        }
        state = .stopped
        let backgroundCompletion = Utilities.completion(on: .global(qos: .background), completion: completion)
        backgroundCompletion(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard case .running = self.state else {
            return
        }
        state = .stopped
        let backgroundCompletion = Utilities.completion(on: .global(qos: .background), completion: completion)
        backgroundCompletion(.failure(error))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard case .running = self.state else {
            return
        }
        state = .stopped
        let backgroundCompletion = Utilities.completion(on: .global(qos: .background), completion: completion)

        let script = """

        Array.from( document.getElementsByTagName('img') ).sort( function(a, b) {
            return (b.clientWidth * b.clientHeight)-(a.clientWidth * a.clientHeight);
        } )/* .filter( function( img ) {
            return window.getComputedStyle( img ) != 'none';
        } ) */.filter( function( img ) {
            return true;
            var bounding = img.getBoundingClientRect();
            return (bounding.bottom >= 0 ||
                    bounding.right >= 0 ||
                    bounding.left <= (window.innerWidth || document.documentElement.clientWidth) ||
                    bounding.top <= (window.innerHeight || document.documentElement.clientHeight))
        } ).map( function( img ) {
            return img.src;
        } ).filter( function( src ) {
            return src.length > 0;
        } )

        """

        // TODO: Work out what thread I'm on here.
        webView.evaluateJavaScript(script) { (result, error) in
            guard let result = result else {
                guard let error = error else {
                    backgroundCompletion(.failure(WebViewDownloaderError.notFound))
                    return
                }
                backgroundCompletion(.failure(error))
                return
            }
            guard let images = result as? [String] else {
                backgroundCompletion(.failure(WebViewDownloaderError.notFound))
                return
            }
            print("DownloadManager: \(self.url.absoluteString) => \(images))")
            guard
                let selection = images.first,
                let url = URL(string: selection) else {
                    backgroundCompletion(.failure(WebViewDownloaderError.notFound))
                    return
            }
            backgroundCompletion(.success(url))
        }

    }

    func cancel() {
        DispatchQueue.main.async {
            let backgroundCompletion = Utilities.completion(on: .global(qos: .background), completion: self.completion)
            switch self.state {
            case .idle:
                backgroundCompletion(.failure(WebViewDownloaderError.cancelled))
            case .running:
                self.webView!.stopLoading()
                backgroundCompletion(.failure(WebViewDownloaderError.cancelled))
            case .stopped:
                return
            }
        }
    }

    override var description: String {
        return URLComponents(unsafeString: self.url.absoluteString)?.host ?? "unknown"
    }

}
