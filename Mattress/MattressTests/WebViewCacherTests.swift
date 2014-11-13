//
//  WebViewCacherTests.swift
//  Mattress
//
//  Created by David Mauro on 11/13/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

import XCTest
import UIKit

class WebViewCacherTests: XCTestCase {

    func testCompletionHandlerIsCalledIfLoadedHandlerReturnsTrue() {
        let cacher = WebViewCacher()
        cacher.loadedHandler = { webView in
            return true
        }
        var complete = false
        cacher.completionHandler = { cacher in
            complete = true
        }
        let webView = UIWebView()
        cacher.webViewDidFinishLoad(webView)
        XCTAssertTrue(complete, "Completion handler was not called")
    }

    func testCompletionHandlerIsNotCalledIfLoadedHandlerReturnsFalse() {
        let cacher = WebViewCacher()
        cacher.loadedHandler = { webView in
            return false
        }
        var complete = false
        cacher.completionHandler = { cacher in
            complete = true
        }
        let webView = UIWebView()
        cacher.webViewDidFinishLoad(webView)
        XCTAssertFalse(complete, "Completion handler was not called")
    }
}
