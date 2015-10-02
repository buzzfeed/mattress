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
    to signal that they should be stored in the Mattress
    disk cache.
*/
class WebViewCacher: NSObject, UIWebViewDelegate {

    // MARK: - Properties

    /// Handler called to determine if a webpage is considered loaded.
    var loadedHandler: WebViewLoadedHandler?
    /// Handler called once a webpage has finished loading.
    var completionHandler: WebViewCacherCompletionHandler?
    /// Handler called if a webpage fails to load.
    var failureHandler: ((NSError) -> ())? = nil
    /// Main URL for the webpage request.
    private var mainDocumentURL: NSURL?
    /// Webview used to load the webpage.
    private var webView: UIWebView?

    // MARK: - Instance Methods

    /**
        Uses the associated mainDocumentURL to determine if it
        thinks it is responsible for a given NSURLRequest.
    
        This is necessary because the UIWebView can fire off requests
        without telling the webViewDelegate about them, so the
        URLProtocol will catch them for us, which should result in
        this method being called.
        
        :param: request The request in question.

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
        Creates a mutable request for a given request that should
        be handled by the WebViewCacher.
    
        The property signaling that the request should be stored in
        the Mattress disk cache will be added.
    
        :param: request The request.
    
        :returns: A mutable request based on the requested passed in.
    */
    func mutableRequestForRequest(request: NSURLRequest) -> NSMutableURLRequest {
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        NSURLProtocol.setProperty(true, forKey: MattressCacheRequestPropertyKey, inRequest: mutableRequest)
        return mutableRequest
    }

    /**
        mattressCacheURL:loadedHandler:completionHandler: is the main
        entry point for dealing with WebViewCacher. Calling this method
        will result in a new UIWebView being generated to cache all the
        requests associated with the given NSURL to the Mattress disk cache.
    
        :param: url The url to be cached.
        :param: loadedHandler The handler that will be called every time
            the webViewDelegate's webViewDidFinishLoading method is called.
            This should return a Bool indicating whether we should stop
            loading.
        :param: completionHandler Called once the loadedHandler has returned
            true and we are done caching the requests at the given url.
        :param: completionHandler Called if the webpage fails to load.
    */
    func mattressCacheURL(url: NSURL,
                loadedHandler: WebViewLoadedHandler,
            completionHandler: WebViewCacherCompletionHandler,
               failureHandler: (NSError) -> ()) {
        self.loadedHandler = loadedHandler
        self.completionHandler = completionHandler
        self.failureHandler = failureHandler
        loadURLInWebView(url)
    }

    // MARK: WebView Loading

    /**
        Loads a URL in the webview associated with the WebViewCacher.
    
        :param: url URL of the webpage to be loaded.
    */
    private func loadURLInWebView(url: NSURL) {
        let webView = UIWebView(frame: CGRectZero)
        let request = NSURLRequest(URL: url)
        let mutableRequest = mutableRequestForRequest(request)
        self.webView = webView
        webView.delegate = self
        webView.loadRequest(mutableRequest)
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
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        // We can ignore this error as it just means canceled.
        // http://stackoverflow.com/a/1053411/1084997
        if error?.code == -999 {
            return
        }

        if let error = error {
            NSLog("WebViewLoadError: %@", error)

            synchronized(self) { () -> Void in
                if let failureHandler = self.failureHandler {
                    failureHandler(error)
                }
                self.failureHandler = nil
            }
        }
    }

    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        mainDocumentURL = request.mainDocumentURL
        if !URLCache.requestShouldBeStoredInMattress(request) {
            let mutableRequest = mutableRequestForRequest(request)
            webView.loadRequest(mutableRequest)
            return false
        }
        return true
    }
}
