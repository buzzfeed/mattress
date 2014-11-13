//
//  URLProtocolTests.swift
//  Mattress
//
//  Created by David Mauro on 11/13/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import XCTest

class URLProtocolTests: XCTestCase {
    override func setUp() {
        super.setUp()
        mockProtocolIsRegistered = false
        // Private URLProtocol caches
        caches = []
    }

    func testProtocolRegistersItselfWhenFirstCacheIsCreated() {
        XCTAssertFalse(mockProtocolIsRegistered, "Should not have registered yet")
        let cache = MockCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        XCTAssertTrue(mockProtocolIsRegistered, "Protocol did not register itself")
    }

    func testProtocolUnregistersOnlyWhenLastCacheIsRemoved() {
        XCTAssertFalse(mockProtocolIsRegistered, "Should not have registered yet")
        let cache1 = MockCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        XCTAssertTrue(mockProtocolIsRegistered, "Protocol did not register itself")
        let cache2 = MockCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        // autoreleasepool does not call deinit, so have this instead :(
        cache2.fakeDeinit()
        XCTAssertTrue(mockProtocolIsRegistered, "Protocol was not still registered after deiniting the latter cache")
        cache1.fakeDeinit()
        XCTAssertFalse(mockProtocolIsRegistered, "Should have unregistered when both caches went away")
    }
}

// Mark: - Mocks

var mockProtocolIsRegistered = false

class MockProtocol: URLProtocol {
    override class func registerProtocol(shouldRegister: Bool) {
        mockProtocolIsRegistered = shouldRegister
    }
}

class MockCache: URLCache {
    func fakeDeinit() {
        MockProtocol.removeCache(self)
    }

    override func addToProtocol(shouldAdd: Bool) {
        if shouldAdd {
            MockProtocol.addCache(self)
        } else {
            MockProtocol.removeCache(self)
        }
    }
}
