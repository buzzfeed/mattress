//
//  URLProtocol.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import Foundation

var caches: [URLCache] = []
let cacheLockObject = NSObject()

private let URLProtocolHandledRequestKey = "URLProtocolHandledRequestKey"
public var shouldRetrieveFromOfflineCacheByDefault = false

/**
    URLProtocol is an NSURLProtocol in charge of ensuring
    that any requests made as a result of a WebViewCacher
    are forwarded back to the WebViewCacher responsible.

    Additionally it ensures that when we are offline, we will
    use the offline diskCache if possible.
*/
class URLProtocol: NSURLProtocol, NSURLConnectionDataDelegate {
    var connection: NSURLConnection?

    // MARK: - Class Methods

    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if NSURLProtocol.propertyForKey(URLProtocolHandledRequestKey, inRequest: request) != nil {
            return false
        }

        // In the case that we're trying to offlineCache, we should always use this protocol
        if let webViewCacher = webViewCacherForRequest(request) {
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
        // and if there is something in the offline cache to get fetched.
        let scheme = request.URL?.scheme
        if scheme == "http" || scheme == "https" {
            if shouldRetrieveFromOfflineCacheByDefault {
                if let cache = NSURLCache.sharedURLCache() as? URLCache {
                    if cache.hasOfflineCachedResponseForRequest(request) {
                        return true
                    }
                }
            }
        }

        // Otherwise only use this protocol when offline
        return isOffline
    }

    /**
        addCache: Adds another URLCache that should
        be checked in with when deciding which/if a
        WebViewCacher is responsible for a request.
    
        This method is responsible for having this
        protocol registered. It will only register
        itself when there is a URLCache that has been
        added.
    */
    class func addCache(cache: URLCache) {
        synchronized(cacheLockObject, { () -> Void in
            if caches.count == 0 {
                self.registerProtocol(true)
            }
            caches.append(cache)
        })
    }

    /**
        removeCache: removes the URLCache from the
        list of caches that should be used to find the
        WebViewCacher responsible for requests.
    
        If there are no more caches, this protocol will
        unregister itself.
    */
    class func removeCache(cache: URLCache) {
        synchronized(cacheLockObject) { () -> Void in
            var index = find(caches, cache)
            if let index = index {
                caches.removeAtIndex(index)
                if caches.count == 0 {
                    self.registerProtocol(false)
                }
            }
        }
    }

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
    */
    private class func webViewCacherForRequest(request: NSURLRequest) -> WebViewCacher? {
        var webViewCacherReturn: WebViewCacher? = nil
        
        synchronized(cacheLockObject) { () -> Void in
            for i in reverse(0..<caches.count) {
                let cache = caches[i]
                if let webViewCacher = cache.webViewCacherOriginatingRequest(request) {
                    webViewCacherReturn = webViewCacher
                    break
                }
            }
        }
        
        return webViewCacherReturn
    }

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
        var mutableRequest = URLProtocol.mutableCanonicalRequestForRequest(request)
        if let
            cache = NSURLCache.sharedURLCache() as? URLCache,
            cachedResponse = cache.cachedResponseForRequest(mutableRequest)
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
