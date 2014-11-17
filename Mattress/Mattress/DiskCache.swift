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
    let searchPathDirectory: NSSearchPathDirectory
    let cacheSize: Int

    init(path: String, searchPathDirectory: NSSearchPathDirectory, cacheSize: Int) {
        self.path = path
        self.searchPathDirectory = searchPathDirectory
        self.cacheSize = cacheSize

        // Plist to track a list of mainDocumentURLs
        // in order that they should be dropped as we hit
        // our limit
    }

    func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) -> Bool {
        var success = false
        let path = diskPathForRequest(request)?.path
        if let path = path {
            println("Write to: \(path)")
            success = NSKeyedArchiver.archiveRootObject(cachedResponse, toFile: path)
        }
        return success
    }

    func cachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        var response: NSCachedURLResponse?
        let path = diskPathForRequest(request)?.path
        if let path = path {
            response = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? NSCachedURLResponse
        }
        return response
    }

    /*!
        @method diskPathForRequest:
        @abstract diskPathForRequest: will create a deterministic
        file NSURL based on a request URL. The path to the file will be
        <caches dir>/<DiskCache path>/<request URL>
    */
    func diskPathForRequest(request: NSURLRequest) -> NSURL? {
        var url: NSURL?
        var filename = request.URL.absoluteString
        if let string = filename {
            filename = hashForURLString(string)
        }
        if let filename = filename {
            var baseURL = diskPath()
            if let baseURL = baseURL {
                url = NSURL(string: filename, relativeToURL: baseURL)
            }
        }
        return url
    }

    /*!
        @method diskPath
        @abstract diskPath returns an NSURL to the filePath root
        where all files for this diskCache should be stored.
    */
    func diskPath() -> NSURL? {
        var url: NSURL?
        var baseURL = NSFileManager.defaultManager().URLForDirectory(searchPathDirectory,
            inDomain: .UserDomainMask, appropriateForURL: nil, create: false, error: nil)
        if let baseURL = baseURL {
            url = NSURL(string: "\(path)/", relativeToURL: baseURL)
            if let url = url {
                if let urlString = url.absoluteString {
                    var isDir : ObjCBool = false
                    if !NSFileManager.defaultManager().fileExistsAtPath(urlString, isDirectory: &isDir) {
                        NSFileManager.defaultManager().createDirectoryAtURL(url,
                            withIntermediateDirectories: true, attributes: nil, error: nil)
                    }
                }
            }
        }
        return url
    }

    func hashForURLString(string: String) -> String? {
        // Temp, just convert filename to hex, should be a hash
        let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        var out = data?.description
        out = out?.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        out = out?.stringByReplacingOccurrencesOfString("<", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        out = out?.stringByReplacingOccurrencesOfString(">", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        return out
    }
}
