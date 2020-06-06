//
//  WebViewDownloader.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 27/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

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

final class WebViewThumbnailSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == UIImage, SubscriberType.Failure == Error {
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

    typealias Output = UIImage
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
//            let delegate = UIApplication.shared.delegate as! AppDelegate
//            let navigationController = delegate.window?.rootViewController as! UINavigationController
//            let controller = navigationController.viewControllers.first!
//            controller.view.addSubview(self.webView)
//            controller.view.sendSubviewToBack(self.webView)
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


//struct ThumbnailPublisher<UIImage>: Publisher {
//
//    typealias Output = UIImage
//    typealias Failure = Error
//
//    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
//        let subscription = Subscription(subscriber: subscriber)
//        subscriber.receive(subscription: subscription)
//    }
//
//}
