//
//  URLCache.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import Foundation

public let MattressOfflineCacheRequestPropertyKey = "MattressOfflineCacheRequest"
public let MattressAvoidCacheRequestPropertyKey = "MattressAvoidCacheRequestPropertyKey" // for the main document that we don't want to cache
let URLCacheStoredRequestPropertyKey = "URLCacheStoredRequest"

private let kB = 1024
private let MB = kB * 1024
private let ArbitrarilyLargeSize = MB * 100

/**
    URLCache is an NSURLCache with an additional diskCache used
    only for storing requests that should be available offline.
*/
public class URLCache: NSURLCache {
    
    var isOfflineHandler: (() -> Bool)?
    
    var offlineCache: DiskCache
    var cachers: [WebViewCacher] = []

    /*
    We need to override this because the connection
    might decide not to cache something if it decides
    the cache is too small wrt the size of the request
    to be cached.
    */
    override public var diskCapacity: Int {
        get {
            return ArbitrarilyLargeSize
        }
        set (value) {}
    }

    // MARK: - Class Methods

    class func requestShouldBeStoredOffline(request: NSURLRequest) -> Bool {
        if let value = NSURLProtocol.propertyForKey(MattressOfflineCacheRequestPropertyKey, inRequest: request) as? Bool {
            return value
        }
        return false
    }

    // MARK: - Instance Methods

    /**
        Initializes a URLCache.

        :param: memoryCapacity The memory capacity of the cache in bytes
        :param: diskCapacity The disk capacity of the cache in bytes
        :param: diskPath The location in the application's default cache
            directory at which to store the on-disk cache
        :param: offlineDiskCapacity The disk capacity of the cache dedicated
            to requests that should be available offline
        :param: offlineDiskPath The location at which to store the offline
            disk cache, relative to the specified offlineSearchPathDirectory
        :param: offlineSearchPathDirectory The searchPathDirectory to use as
            the location for the offline disk cache
        :param: isOfflineHandler A handler that will be called as needed to
            determine if the offline cache should be used
    */
    public init(memoryCapacity: Int, diskCapacity: Int, diskPath path: String?, offlineDiskCapacity: Int, offlineDiskPath offlinePath: String?,
        offlineSearchPathDirectory searchPathDirectory: NSSearchPathDirectory, isOfflineHandler: (() -> Bool)?)
    {
        offlineCache = DiskCache(path: offlinePath, searchPathDirectory: searchPathDirectory, maxCacheSize: offlineDiskCapacity)
        self.isOfflineHandler = isOfflineHandler
        super.init(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: path)
        addToProtocol(true)
    }

    deinit {
        addToProtocol(false)
    }

    func addToProtocol(shouldAdd: Bool) {
        if shouldAdd {
            URLProtocol.addCache(self)
        } else {
            URLProtocol.removeCache(self)
        }
    }

    /**
        This method will attempt to find a WebViewCacher responsible
        for a given request.
    */
    func webViewCacherOriginatingRequest(request: NSURLRequest) -> WebViewCacher? {
        for cacher in cachers {
            if cacher.didOriginateRequest(request) {
                return cacher
            }
        }
        return nil
    }

    // MARK: Public

    override public func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) {
        if URLCache.requestShouldBeStoredOffline(request) {
            let success = offlineCache.storeCachedResponse(cachedResponse, forRequest: request)
        } else {
            super.storeCachedResponse(cachedResponse, forRequest: request)
            // If we've already stored this in the offline cache, update it
            if offlineCache.hasCacheForRequest(request) {
                offlineCache.storeCachedResponse(cachedResponse, forRequest: request)
            }
        }
    }

    public override func cachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        var cachedResponse = offlineCache.cachedResponseForRequest(request)
        if cachedResponse != nil {
            return cachedResponse
        }
        return super.cachedResponseForRequest(request)
    }

    /**
        This method should be called to signal that the entire page at a url
        should be downloaded and stored in the offlineCache. Any urls cached
        in this way will be available when the device is offline.
    
        :param: url The url of a webpage to download
        :param: loadedHandler A handler that will be called every time the
            UIWebView used to load the request calls its delegate's
            webViewDidFinishLoad method. This handler will receive the webView
            and should return true if we are done loading the page, or false
            if we should continue loading.
    */
    public func offlineCacheURL(url: NSURL,
                      loadedHandler: WebViewLoadedHandler,
                    completeHandler: (() ->Void)? = nil,
                     failureHandler: ((NSError) ->Void)? = nil) {
        let webViewCacher = WebViewCacher()
        
        synchronized(self) {
            self.cachers.append(webViewCacher)
        }
        
        var failureHandler = failureHandler
        var completeHandler = completeHandler

        webViewCacher.offlineCacheURL(url, loadedHandler: loadedHandler, completionHandler: { (webViewCacher) -> () in
            synchronized(self) {
                if let index = find(self.cachers, webViewCacher) {
                    self.cachers.removeAtIndex(index)
                }
                
                completeHandler?()
                
                completeHandler = nil
            }
            }, failureHandler: { (error) -> () in
                
                failureHandler?(error)
                
                failureHandler = nil
            })
            
        }
}
