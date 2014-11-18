//
//  WebViewCacher.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import UIKit

public typealias WebViewLoadedHandler = (webView: UIWebView) -> (Bool)
typealias WebViewCacherCompletionHandler = ((webViewCacher: WebViewCacher) -> ())

/*!
    @class WebViewCacher
    WebViewCacher is in charge of loading all of the
    requests associated with a url and ensuring they
    are all stored in the precious offline cache.
*/
class WebViewCacher: NSObject, UIWebViewDelegate {
    var loadedHandler: WebViewLoadedHandler?
    var completionHandler: WebViewCacherCompletionHandler?
    var mainDocumentURL: NSURL?
    var webView: UIWebView?

    func didOriginateRequest(request: NSURLRequest) -> Bool {
        if let mainDocumentURL = mainDocumentURL {
            if request.mainDocumentURL == mainDocumentURL {
                return true
            }
        }
        return false
    }

    /*!
        @method mutableRequestForRequest
        @abstract Creates a mutable request for a given request
        that should be handled by the WebViewCacher.
    */
    func mutableRequestForRequest(request: NSURLRequest) -> NSMutableURLRequest {
        var mutableRequest = request.mutableCopy() as NSMutableURLRequest
        NSURLProtocol.setProperty(true, forKey: MattressOfflineCacheRequestPropertyKey, inRequest: mutableRequest)
        return mutableRequest
    }

    func offlineCacheURL(url: NSURL, loadedHandler: WebViewLoadedHandler, completionHandler: WebViewCacherCompletionHandler) {
        self.loadedHandler = loadedHandler
        self.completionHandler = completionHandler
        loadURLInWebView(url)
    }

    // Mark: - WebView Loading

    private func loadURLInWebView(url: NSURL) {
        let webView = UIWebView(frame: CGRectZero)
        let request = NSURLRequest(URL: url)
        var mutableRequest = mutableRequestForRequest(request)
        webView.delegate = self
        webView.loadRequest(mutableRequest as NSURLRequest)
        self.webView = webView
    }

    // Mark: - UIWebViewDelegate
    // TODO: We should do some JS injection to better cache the loaded event

    func webViewDidFinishLoad(webView: UIWebView) {
        var isComplete = true
        if let loadedHandler = loadedHandler {
            isComplete = loadedHandler(webView: webView)
        }
        if isComplete {
            if let completionHandler = completionHandler {
                completionHandler(webViewCacher: self)
            }
        }
    }

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        // Ensure all requests from this webView include the offline caching header
        mainDocumentURL = request.mainDocumentURL
        if !URLCache.requestShouldBeStoredOffline(request) {
            let mutableRequest = mutableRequestForRequest(request)
            webView.loadRequest(mutableRequest)
            return false
        }
        return true
    }
}
