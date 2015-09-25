//
//  URLProtocol.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import Foundation

/// Caches to be consulted
var caches: [URLCache] = []
/// Provides locking for multi-threading sensitive operations
let cacheLockObject = NSObject()

/// Used to indicate that a request has been handled by this URLProtocol
private let URLProtocolHandledRequestKey = "URLProtocolHandledRequestKey"
public var shouldRetrieveFromMattressCacheByDefault = false

/**
    URLProtocol is an NSURLProtocol in charge of ensuring
    that any requests made as a result of a WebViewCacher
    are forwarded back to the WebViewCacher responsible.

    Additionally it ensures that when we are offline, we will
    use the Mattress diskCache if possible.
*/
class URLProtocol: NSURLProtocol, NSURLConnectionDataDelegate {

    /// Used to stop loading
    var connection: NSURLConnection?
    
    static var shouldRetrieveFromMattressCacheByDefault = false
    
    // MARK: - Class Methods

    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if NSURLProtocol.propertyForKey(URLProtocolHandledRequestKey, inRequest: request) != nil {
            return false
        }

        // In the case that we're trying to diskCache, we should always use this protocol
        if webViewCacherForRequest(request) != nil {
            return true
        }

        var isOffline = false
        if let cache = NSURLCache.sharedURLCache() as? URLCache {
            if let handler = cache.isOfflineHandler {
                isOffline = handler()
            }
        }

        // Online requests get a chance to opt out of retreival from cache
        if !isOffline &&
            NSURLProtocol.propertyForKey(MattressAvoidCacheRetreiveOnlineRequestPropertyKey,
                inRequest: request) as? Bool == true
        {
            return false
        }

        // Online requests that didn't opt out will get included if turned on
        // and if there is something in the Mattress disk cache to get fetched.
        let scheme = request.URL?.scheme
        if scheme == "http" || scheme == "https" {
            if shouldRetrieveFromMattressCacheByDefault {
                if let cache = NSURLCache.sharedURLCache() as? URLCache {
                    if cache.hasMattressCachedResponseForRequest(request) {
                        return true
                    }
                }
            }
        }

        // Otherwise only use this protocol when offline
        return isOffline
    }

    /**
        Adds a URLCache that should be consulted
        when deciding which/if a WebViewCacher is
        responsible for a request.
    
        This method is responsible for having this
        protocol registered. It will only register
        itself when there is a URLCache that has been
        added.
    
        :param: cache The cache to be added.
    */
    class func addCache(cache: URLCache) {
        synchronized(cacheLockObject) { () -> Void in
            if caches.count == 0 {
                self.registerProtocol(true)
            }
            caches.append(cache)
        }
    }

    /**
        Removes a URLCache from the list of caches
        that should be used to find the WebViewCacher
        responsible for requests.
    
        If there are no more caches, this protocol will
        unregister itself.
    
        :param: cache The cache to be removed.
    */
    class func removeCache(cache: URLCache) {
        synchronized(cacheLockObject) { () -> Void in
            if let index = caches.indexOf(cache) {
                caches.removeAtIndex(index)
                if caches.count == 0 {
                    self.registerProtocol(false)
                }
            }
        }
    }

    /**
        Registers and unregisters this class for URL handling.
    
        :param: shouldRegister If true, registers this class
            for URL handling. If false, unregisters the class.
    */
    class func registerProtocol(shouldRegister: Bool) {
        if shouldRegister {
            self.registerClass(self)
        } else {
            self.unregisterClass(self)
        }
    }

    /**
        Finds the webViewCacher responsible for a request by
        asking each of its URLCaches in reverse order.
    
        :param: request The request.
        
        :returns: The WebViewCacher responsible for the request.
    */
    private class func webViewCacherForRequest(request: NSURLRequest) -> WebViewCacher? {
        var webViewCacherReturn: WebViewCacher? = nil
        
        synchronized(cacheLockObject) { () -> Void in
            for cache in caches.reverse() {
                if let webViewCacher = cache.webViewCacherOriginatingRequest(request) {
                    webViewCacherReturn = webViewCacher
                    break
                }
            }
        }
        
        return webViewCacherReturn
    }

    /**
        Helper method that returns and configures mutable copy
        of a request.
    
        :param: request The request.
    
        :returns: The mutable, configured copy of the request.
    */
    private class func mutableCanonicalRequestForRequest(request: NSURLRequest) -> NSMutableURLRequest {
        var mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        mutableRequest.cachePolicy = .ReturnCacheDataElseLoad
        if let webViewCacher = webViewCacherForRequest(request) {
            mutableRequest = webViewCacher.mutableRequestForRequest(request)
        }

        NSURLProtocol.setProperty(true, forKey: URLProtocolHandledRequestKey, inRequest: mutableRequest)
        return mutableRequest
    }

    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return mutableCanonicalRequestForRequest(request)
    }

    override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, toRequest:b)
    }

    // MARK: - Instance Methods

    override func startLoading() {
        let mutableRequest = URLProtocol.mutableCanonicalRequestForRequest(request)
        if let
            cache = NSURLCache.sharedURLCache() as? URLCache,
            cachedResponse = cache.cachedResponseForRequest(mutableRequest),
            response = cachedResponse.response as? NSHTTPURLResponse
            where response.statusCode < 400
        {
            client?.URLProtocol(self, cachedResponseIsValid: cachedResponse)
            return
        }
        self.connection = NSURLConnection(request: mutableRequest, delegate: self)
    }

    override func stopLoading() {
        connection?.cancel()
        connection = nil
    }

    // Mark: - NSURLConnectionDataDelegate Methods

    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .Allowed)
    }

    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.client?.URLProtocol(self, didLoadData: data)
    }

    func connectionDidFinishLoading(connection: NSURLConnection) {
        self.client?.URLProtocolDidFinishLoading(self)
    }

    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self.client?.URLProtocol(self, didFailWithError: error)
    }
}
