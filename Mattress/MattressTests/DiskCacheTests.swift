//
//  DiskCacheTests.swift
//  Mattress
//
//  Created by David Mauro on 11/14/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import XCTest

class DiskCacheTests: XCTestCase {

    func testDiskPathForRequestIsDeterministic() {
        let url = NSURL(string: "foo://bar")!
        let request1 = NSURLRequest(URL: url)
        let request2 = NSURLRequest(URL: url)
        let diskCache = DiskCache(path: "test", searchPathDirectory: .DocumentDirectory, cacheSize: 1024)
        let path = diskCache.diskPathForRequest(request1)
        XCTAssertNotNil(path, "Path for request was nil")
        XCTAssert(path == diskCache.diskPathForRequest(request2), "Requests for the same url did not match")
    }

    func testDiskPathsForDifferentRequestsAreNotEqual() {
        let url1 = NSURL(string: "foo://bar")!
        let url2 = NSURL(string: "foo://baz")!
        let request1 = NSURLRequest(URL: url1)
        let request2 = NSURLRequest(URL: url2)
        let diskCache = DiskCache(path: "test", searchPathDirectory: .DocumentDirectory, cacheSize: 1024)
        let path1 = diskCache.diskPathForRequest(request1)
        let path2 = diskCache.diskPathForRequest(request2)
        XCTAssert(path1 != path2, "Paths should not be matching")
    }

    func testStoreCachedResponseReturnsTrue() {
        let data = "hello, world".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let url = NSURL(string: "foo://bar")!
        let request = NSURLRequest(URL: url)
        let response = NSURLResponse(URL: url, MIMEType: "text/html", expectedContentLength: data.length, textEncodingName: nil)
        let userInfo = ["foo" : "bar"]
        let cachedResponse = NSCachedURLResponse(response: response, data: data, userInfo: userInfo, storagePolicy: .Allowed)
        let diskCache = DiskCache(path: "test", searchPathDirectory: .DocumentDirectory, cacheSize: 1024)
        let success = diskCache.storeCachedResponse(cachedResponse, forRequest: request)
        XCTAssert(success, "Did not save the cached response to disk")
    }

    func testCachedResponseCanBeArchivedAndUnarchivedWithoutDataLoss() {
        // Saw some old reports of keyedArchiver not working well with NSCachedURLResponse
        // so this is just here to make sure things are working on Apple's end
        let data = "hello, world".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let url = NSURL(string: "foo://bar")!
        let request = NSURLRequest(URL: url)
        let response = NSURLResponse(URL: url, MIMEType: "text/html", expectedContentLength: data.length, textEncodingName: nil)
        let userInfo = ["foo" : "bar"]
        let cachedResponse = NSCachedURLResponse(response: response, data: data, userInfo: userInfo, storagePolicy: .Allowed)
        let diskCache = DiskCache(path: "test", searchPathDirectory: .DocumentDirectory, cacheSize: 1024)
        diskCache.storeCachedResponse(cachedResponse, forRequest: request)

        let restored = diskCache.cachedResponseForRequest(request)
        if let restored = restored {
            assertCachedResponsesAreEqual(response1: restored, response2: cachedResponse)
        } else {
            XCTFail("Did not get back a cached response from diskCache")
        }
    }

    func testCacheReturnsCorrectResponseForRequest() {
        let data1 = "hello, world".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let url1 = NSURL(string: "foo://bar")!
        let request1 = NSURLRequest(URL: url1)
        let response1 = NSURLResponse(URL: url1, MIMEType: "text/html", expectedContentLength: data1.length, textEncodingName: nil)
        let userInfo1 = ["foo" : "bar"]
        let cachedResponse1 = NSCachedURLResponse(response: response1, data: data1, userInfo: userInfo1, storagePolicy: .Allowed)

        let data2 = "goodybye, cruel world".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let url2 = NSURL(string: "foo://baz")!
        let request2 = NSURLRequest(URL: url2)
        let response2 = NSURLResponse(URL: url2, MIMEType: "text/javascript", expectedContentLength: data2.length, textEncodingName: nil)
        let userInfo2 = ["baz" : "qux"]
        let cachedResponse2 = NSCachedURLResponse(response: response2, data: data2, userInfo: userInfo2, storagePolicy: .Allowed)

        let diskCache = DiskCache(path: "test", searchPathDirectory: .DocumentDirectory, cacheSize: 1024)
        let success1 = diskCache.storeCachedResponse(cachedResponse1, forRequest: request1)
        let success2 = diskCache.storeCachedResponse(cachedResponse2, forRequest: request2)
        XCTAssert(success1 && success2, "The responses did not save properly")

        let restored1 = diskCache.cachedResponseForRequest(request1)
        if let restored = restored1 {
            assertCachedResponsesAreEqual(response1: restored, response2: cachedResponse1)
        } else {
            XCTFail("Did not get back a cached response from diskCache")
        }
        let restored2 = diskCache.cachedResponseForRequest(request2)
        if let restored = restored2 {
            assertCachedResponsesAreEqual(response1: restored, response2: cachedResponse2)
        } else {
            XCTFail("Did not get back a cached response from diskCache")
        }
    }

    // Mark: - Test Helpers

    func assertCachedResponsesAreEqual(#response1 : NSCachedURLResponse, response2: NSCachedURLResponse) {
        XCTAssert(response1.data == response2.data, "Data did not match")
        XCTAssert(response1.response.URL == response2.response.URL, "Response did not match")
        XCTAssert(response1.userInfo!.description == response2.userInfo!.description, "userInfo didn't match")
    }
}
