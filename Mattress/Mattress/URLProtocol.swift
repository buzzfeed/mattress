//
//  URLProtocol.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import Foundation

var caches: [URLCache] = []
private let URLProtocolHandledRequestKey = "URLProtocolHandledRequestKey"

/*!
    @class URLProtocol
    URLProtocol is the protocol in charge of ensuring
    that any requests made as a result of the WebViewCacher
    are forwarded back to the WebViewCacher responsible.
*/
class URLProtocol: NSURLProtocol, NSURLConnectionDataDelegate {
    var connection: NSURLConnection?

    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if NSURLProtocol.propertyForKey(URLProtocolHandledRequestKey, inRequest: request) != nil {
            return false
        }

        // Only handle this if a WebViewCacher is responsible
        // for this request
        if let webViewCacher = webViewCacherForRequest(request) {
            return true
        }
        return false
    }

    /*!
        @method addCache:
        @abstract Adds another cache that should be
        should be checked in with when deciding which
        WebViewCacher is responsible for a request.
    */
    class func addCache(cache: URLCache) {
        if caches.count == 0 {
            registerProtocol(true)
        }
        caches.append(cache)
    }

    /*!
        @method removeCache:
        @abstract Remove the cache from the list of
        caches that should be used to find the
        WebViewCacher responsible for requests.
    */
    class func removeCache(cache: URLCache) {
        var index = find(caches, cache)
        if let index = index {
            caches.removeAtIndex(index)
            if caches.count == 0 {
                registerProtocol(false)
            }
        }
    }

    class func registerProtocol(shouldRegister: Bool) {
        if shouldRegister {
            NSURLProtocol.registerClass(self)
        } else {
            NSURLProtocol.unregisterClass(self)
        }
    }

    class func webViewCacherForRequest(request: NSURLRequest) -> WebViewCacher? {
        for i in reverse(0..<caches.count) {
            let cache = caches[i]
            if let webViewCacher = cache.webViewCacherOriginatingRequest(request) {
                return webViewCacher
            }
        }
        return nil
    }

    class func mutableCanonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        var mutableRequest = request.mutableCopy() as NSMutableURLRequest
        if let webViewCacher = webViewCacherForRequest(request) {
            mutableRequest = webViewCacher.mutableRequestForRequest(request)
        }
        NSURLProtocol.setProperty(true, forKey: URLProtocolHandledRequestKey, inRequest: mutableRequest)
        return mutableRequest
    }

    // Mark: - Class Overrides

    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return mutableCanonicalRequestForRequest(request)
    }

    override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, toRequest:b)
    }

    // Mark: - Loading

    override func startLoading() {
        var mutableRequest = URLProtocol.mutableCanonicalRequestForRequest(request)
        self.connection = NSURLConnection(request: mutableRequest, delegate: self)
    }

    override func stopLoading() {
        connection?.cancel()
        connection = nil
    }

    // Mark: - NSURLConnectionDataDelegate Methods

    func connection(connection: NSURLConnection, willCacheResponse cachedResponse: NSCachedURLResponse) -> NSCachedURLResponse? {
        return cachedResponse // TODO: Can we check on whether we should store this
    }

    func connection(connection: NSURLConnection!, didReceiveResponse response: NSURLResponse) {
        // TODO: Can we check here if we stored this request and if not manuall do it?
        self.client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .Allowed)
    }

    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.client?.URLProtocol(self, didLoadData: data)
    }

    func connectionDidFinishLoading(connection: NSURLConnection) {
        self.client?.URLProtocolDidFinishLoading(self)
    }

    func connection(connection: NSURLConnection!, didFailWithError error: NSError) {
        self.client?.URLProtocol(self, didFailWithError: error)
    }
}
