//
//  URLCacheTests.swift
//  Mattress
//
//  Created by David Mauro on 11/13/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import XCTest

private let url = NSURL(string: "foo://bar")!

class URLCacheTests: XCTestCase {

    func testRequestShouldBeStoredOffline() {
        var mutableRequest = NSMutableURLRequest(URL: url)
        NSURLProtocol.setProperty(true, forKey: MattressOfflineCacheRequestPropertyKey, inRequest: mutableRequest)
        XCTAssert(URLCache.requestShouldBeStoredOffline(mutableRequest), "")
    }

    func testOfflineRequestGoesToOfflineDiskCache() {
        var mutableRequest = NSMutableURLRequest(URL: url)
        NSURLProtocol.setProperty(true, forKey: MattressOfflineCacheRequestPropertyKey, inRequest: mutableRequest)

        var didCallMock = false
        let cache = MockURLCacheWithMockDiskCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        cache.mockDiskCache.storeCacheCalledHandler = {
            didCallMock = true
        }
        let response = NSCachedURLResponse()
        cache.storeCachedResponse(response, forRequest: mutableRequest)
        XCTAssertTrue(didCallMock, "Offline cache storage method was not called")
    }

    func testStandardRequestDoesNotGoToOfflineDiskCache() {
        var mutableRequest = NSMutableURLRequest(URL: url)

        var didCallMock = false
        let cache = MockURLCacheWithMockDiskCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        cache.mockDiskCache.storeCacheCalledHandler = {
            didCallMock = true
        }
        let response = NSCachedURLResponse()
        cache.storeCachedResponse(response, forRequest: mutableRequest)
        XCTAssertFalse(didCallMock, "Offline cache storage method was called")
    }

    func testCachedResponseIsRetriedFromOfflineDiskCache() {
        let request = NSMutableURLRequest(URL: url)
        let cachedResponse = NSCachedURLResponse()

        let cache = MockURLCacheWithMockDiskCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        cache.mockDiskCache.retrieveCacheCalledHandler = { request in
            return cachedResponse
        }
        var response = cache.cachedResponseForRequest(request)
        if let response = response {
            XCTAssert(response == cachedResponse, "Response did not match")
        } else {
            XCTFail("No response returned from cache")
        }
    }

    func testOfflineRequestGeneratesWebViewCacher() {
        let cache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        XCTAssert(cache.cachers.count == 0, "Cache should not start with any cachers")
        cache.offlineCacheURL(url) { webView in
            return true
        }
        XCTAssert(cache.cachers.count == 1, "Should have created a single WebViewCacher")
    }

    func testGettingWebViewCacherResponsibleForARequest() {
        let request = NSURLRequest(URL: url)
        let cacher1 = SourceCache()
        let cacher2 = WebViewCacher()

        let cache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        cache.cachers.append(cacher1)
        cache.cachers.append(cacher2)
        var source = cache.webViewCacherOriginatingRequest(request)
        if let source = source {
            XCTAssert(source == cacher1, "Returned the incorrect cacher")
        } else {
            XCTFail("No source cacher found")
        }
    }
}

// Mark: - An ode to Xcode being the worst -OR- locally scoped subclasses are supposed to work but don't

class SourceCache: WebViewCacher {
    override func didOriginateRequest(request: NSURLRequest) -> Bool {
        return true
    }
}

class MockDiskCache: DiskCache {
    var storeCacheCalledHandler: (() -> ())?
    var retrieveCacheCalledHandler: ((request: NSURLRequest) -> (NSCachedURLResponse?))?

    override func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) -> Bool {
        storeCacheCalledHandler?()
        return true
    }

    override func cachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        if let handler = retrieveCacheCalledHandler {
            return handler(request: request)
        }
        return nil
    }
}
class MockURLCacheWithMockDiskCache: URLCache {
    var mockDiskCache: MockDiskCache {
        return offlineCache as MockDiskCache
    }

    override init(memoryCapacity: Int, diskCapacity: Int, diskPath path: String?) {
        super.init(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: path)

        offlineCache = MockDiskCache(path: "test", searchPathDirectory: .DocumentDirectory, cacheSize: 1024)
    }
}

class MockCacher: WebViewCacher {
    override func offlineCacheURL(url: NSURL, loadedHandler: WebViewLoadedHandler, completionHandler: WebViewCacherCompletionHandler) {}
}
