//
//  WebViewCacher.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import UIKit

public typealias WebViewLoadedHandler = (webView: UIWebView) -> (Bool)
typealias WebViewCacherCompletionHandler = (webViewCacher: WebViewCacher) -> ()

/**
    WebViewCacher is in charge of loading all of the
    requests associated with a url and ensuring that
    all of that webpage's request have the property
    to signal that they should be stored in the NSURLCache's
    offline disk cache.
*/
class WebViewCacher: NSObject, UIWebViewDelegate {

    // MARK: - Properties

    var loadedHandler: WebViewLoadedHandler?
    var completionHandler: WebViewCacherCompletionHandler?
    var failureHandler: ((NSError) -> ())? = nil
    private var mainDocumentURL: NSURL?
    private var webView: UIWebView?

    // MARK: - Instance Methods

    /**
        didOriginateRequest: uses the associated mainDocumentURL
        to determine if it thinks it is responsible for a given
        NSURLRequest.
    
        This is necessary because the UIWebView can fire off requests
        without telling the webViewDelegate about them, so the
        URLProtocol will catch them for us, which should result in
        this method being called.
    
        :returns: A Bool indicating whether this WebViewCacher is
            responsible for that NSURLRequest.
    */
    func didOriginateRequest(request: NSURLRequest) -> Bool {
        if let mainDocumentURL = mainDocumentURL {
            if request.mainDocumentURL == mainDocumentURL || request.URL == mainDocumentURL {
                return true
            }
        }
        return false
    }

    /**
        mutableRequestForRequest: creates a mutable request for a
        given request that should be handled by the WebViewCacher.
    
        The property signaling that the request should be offline
        cached will be added.
    */
    func mutableRequestForRequest(request: NSURLRequest) -> NSMutableURLRequest {
        var mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        NSURLProtocol.setProperty(true, forKey: MattressOfflineCacheRequestPropertyKey, inRequest: mutableRequest)
        return mutableRequest
    }

    /**
        offlineCacheURL:loadedHandler:completionHandler: is the main
        entry point for dealing with WebViewCacher. Calling this method
        will result in a new UIWebView being generated to cache all the
        requests associated with the given NSURL.
    
        :param: url The url to be cached.
        :param: loadedHandler The handler that will be called every time
            the webViewDelegate's webViewDidFinishLoading method is called.
            This should return a Bool indicating whether we should stop
            loading.
        :param: completionHandler Called once the loadedHandler has returned
            true and we are done caching the requests at the given url.
    */
    func offlineCacheURL(url: NSURL,
               loadedHandler: WebViewLoadedHandler,
           completionHandler: WebViewCacherCompletionHandler,
                failureHandler: (NSError) -> ()) {
        self.loadedHandler = loadedHandler
        self.completionHandler = completionHandler
        self.failureHandler = failureHandler
        loadURLInWebView(url)
    }

    // MARK: WebView Loading

    private func loadURLInWebView(url: NSURL) {
        let webView = UIWebView(frame: CGRectZero)
        let request = NSURLRequest(URL: url)
        var mutableRequest = mutableRequestForRequest(request)
        self.webView = webView
        webView.delegate = self
        webView.loadRequest(mutableRequest as NSURLRequest)
        NSLog("WebView loadRequest:%x", self.webView!)
    }

    // MARK: - UIWebViewDelegate

    func webViewDidFinishLoad(webView: UIWebView) {
        var isComplete = true
        synchronized(self) { () -> Void in
            if let loadedHandler = self.loadedHandler {
                isComplete = loadedHandler(webView: webView)
            }
            if isComplete == true {
                webView.stopLoading()
                self.webView = nil
                    
                if let completionHandler = self.completionHandler {
                    completionHandler(webViewCacher: self)
                }
                self.completionHandler = nil
            }
        }
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        // we can ignore this error
        if error.code == -999 {
            return
        }
        
        NSLog("WebViewLoadError:%@", error)
    
        synchronized(self) { () -> Void in
            if let failureHandler = self.failureHandler {
                failureHandler(error)
            }
            self.failureHandler = nil
        }
    }

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        mainDocumentURL = request.mainDocumentURL
        if !URLCache.requestShouldBeStoredOffline(request) {
            let mutableRequest = mutableRequestForRequest(request)
            webView.loadRequest(mutableRequest)
            return false
        }
        return true
    }
}
