//
//  DiskCache.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

/*!
    @class DiskCache
    DiskCache is a NSURLCache replacement that will store
    and retreive NSCachedURLResponses to disk.
*/

import Foundation

class DiskCache {
    let path: String

    init(path: String) {
        self.path = path

        // We need a plist to track which requests belong to which
        // mainDocumentURL so that we can easily remove entire
        // web pages from our cache
    }

    func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) {
        // Save to disk path
    }

    func cachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        // Retrieve from disk path
        return nil
    }

    func diskPathForRequest(request: NSURLRequest) -> NSURL? {
        // Deterministic disk url from a request
        return nil
    }
}
