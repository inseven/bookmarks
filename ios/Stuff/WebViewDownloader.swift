//
//  WebViewDownloader.swift
//  Stuff
//
//  Created by Jason Barrie Morley on 27/05/2020.
//  Copyright © 2020 InSeven Limited. All rights reserved.
//

import Foundation
import WebKit

enum WebViewDownloaderError : Error {
    case notFound
}

class WebViewDownloader: NSObject, WKNavigationDelegate {

    let webView: WKWebView
    let url: URL
    var completion: ((Result<URL, Error>) -> Void)?

    init(url: URL) {
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000)) // TODO: Consider iPhone size
        self.url = url
        super.init()
        webView.navigationDelegate = self
    }

    func start(completion: @escaping (Result<URL, Error>) -> Void) {
        let source = "document.title = 'Custom Title'"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        self.completion = completion
        let myRequest = URLRequest(url: url)
        webView.load(myRequest)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("DID FINISH NAVIGATION!")
        guard let completion = self.completion else {
            return
        }

        let script = """
Array.from( document.getElementsByTagName('img') ).sort( function(a, b) {
    return (b.width * b.height)-(a.width * a.height)
} ).map( function(img) {
    return img.src
} )
"""
        webView.evaluateJavaScript(script) { (result, error) in
            guard let result = result else {
                guard let error = error else {
                    DispatchQueue.global(qos: .background).async {
                        completion(.failure(WebViewDownloaderError.notFound))
                    }
                    return
                }
                DispatchQueue.global(qos: .background).async {
                    completion(.failure(error))
                }
                return
            }
            print("result = \(result)")

            guard
                let images = result as? [String],
                let selection = images.first,
                let url = URL(string: selection) else {
                    DispatchQueue.global(qos: .background).async {
                        completion(.failure(WebViewDownloaderError.notFound))
                    }
                    return
            }
            DispatchQueue.global(qos: .background).async {
                completion(.success(url))
            }
        }

        print("TITLE -> \(webView.title!)")
    }


}
