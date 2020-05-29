//
//  WebViewDownloader.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 27/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

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


class DownloadManager {

    static let shared = DownloadManager()

    let syncQueue: DispatchQueue
    var pending: [AnyHashable]
    var active: Set<AnyHashable>

    init() {
        syncQueue = DispatchQueue(label: "syncQueue")
        pending = []
        active = Set()
    }

    private func debug() {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        let urls = self.active.map { (item) -> String in
            let downloader = item as! WebViewDownloader
            return downloader.description
        }

        print("DownloadManager: \(self.pending.count) pending, \(self.active.count) active \(urls)")
    }

    private func add<T>(_ downloader: T) where T: Hashable {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            self.pending.append(downloader)
            self.run()
        }
    }

    private func remove<T>(_ downloader: T) where T: Hashable {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.async {
            if let index = self.pending.firstIndex(of: downloader) {
                self.pending.remove(at: index)
            }
            self.active.remove(downloader)
            self.run()
        }
    }

    private func run() {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        defer { self.debug() }
        guard
            self.active.count < 1,
            !self.pending.isEmpty,
            let next = self.pending.removeLast() as? WebViewDownloader else {
                return
        }
        _ = self.active.insert(next)
        next.start()
    }

    func downloader(for url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) -> Downloader {
        let userInteractiveCompletion = Utilities.completion(on: .global(qos: .userInteractive), completion: completion)
        var downloader: WebViewDownloader?
        downloader = WebViewDownloader(url: url) { (result) in
            defer { self.remove(downloader!) }
            switch result {
            case .success(let imageUrl):
                DispatchQueue.global(qos: .background).async {
                    guard let image = UIImage.init(contentsOf: imageUrl) else {
                        userInteractiveCompletion(.failure(OpenGraphError.invalidArgument(message: "Unable to fetch image")))
                        return
                    }
                    userInteractiveCompletion(.success(image))
                }
            case .failure(let error):
                userInteractiveCompletion(.failure(error))
            }
        }
        return downloader!
    }

    func schedule<T>(_ downloader: T) where T: Hashable {
        self.add(downloader)
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
            let delegate = UIApplication.shared.delegate as! AppDelegate
            let navigationController = delegate.window?.rootViewController as! UINavigationController
            let controller = navigationController.viewControllers.first!
            controller.view.addSubview(self.webView)
            controller.view.sendSubviewToBack(self.webView)
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
        } ).filter( function( img ) {
            return window.getComputedStyle( img ) != 'none';
        } ).filter( function( img ) {
            var bounding = img.getBoundingClientRect();
            return (bounding.top >= 0 &&
                    bounding.left >= 0 &&
                    bounding.right <= (window.innerWidth || document.documentElement.clientWidth) &&
                    bounding.bottom <= (window.innerHeight || document.documentElement.clientHeight))
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
            print("DownloadManager: \(self.description) => \(images))")
            guard
                let selection = images.first,
                let url = URL(string: selection) else {
                    backgroundCompletion(.failure(WebViewDownloaderError.notFound))
                    return
            }
            backgroundCompletion(.success(url))
        }

        self.webView!.removeFromSuperview()
    }

    func cancel() {
        DispatchQueue.main.async {
            let backgroundCompletion = Utilities.completion(on: .global(qos: .background), completion: self.completion)
            switch self.state {
            case .idle:
                backgroundCompletion(.failure(WebViewDownloaderError.cancelled))
            case .running:
                self.webView!.stopLoading()
                self.webView!.removeFromSuperview()
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
