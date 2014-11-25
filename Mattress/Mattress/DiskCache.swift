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
    enum DictionaryKeys: String {
        case cacheSize = "cacheSize"
        case requestsFilenameArray = "requestsFilenameArray"
    }

    let path: String
    let searchPathDirectory: NSSearchPathDirectory
    let cacheSize: Int
    var currentSize = 0
    var requestCaches: [String] = []

    init(path: String?, searchPathDirectory: NSSearchPathDirectory, cacheSize: Int) {
        self.path = path ?? "offline"
        self.searchPathDirectory = searchPathDirectory
        self.cacheSize = cacheSize
        loadPropertiesFromDisk()
    }

    func loadPropertiesFromDisk() {
        if let plistPath = diskPathForPropertyList()?.path {
            if !NSFileManager.defaultManager().fileExistsAtPath(plistPath) {
                persistPropertiesToDisk()
            } else {
                if let dict = NSDictionary(contentsOfFile: plistPath) {
                    if let currentSize = dict.valueForKey(DictionaryKeys.cacheSize.rawValue) as? Int {
                        self.currentSize = currentSize
                    }
                    if let requestCaches = dict.valueForKey(DictionaryKeys.requestsFilenameArray.rawValue) as? [String] {
                        self.requestCaches = requestCaches
                    }
                }
            }
        }
    }

    func persistPropertiesToDisk() {
        if let plistPath = diskPathForPropertyList()?.path {
            let dict = dictionaryForCache()
            dict.writeToFile(plistPath, atomically: true)
        }
    }

    func trimCacheIfNeeded() {
        while currentSize > cacheSize && !requestCaches.isEmpty {
            let fileName = requestCaches.removeAtIndex(0)
            if let path = diskPathForRequestCacheNamed(fileName)?.path {
                if let attributes = NSFileManager.defaultManager().attributesOfItemAtPath(path, error: nil) as? [String: AnyObject] {
                    if let fileSize = attributes[NSFileSize] as? NSNumber {
                        let size = fileSize.integerValue
                        currentSize -= size
                    }
                }
                NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
            }
        }
    }

    func dictionaryForCache() -> NSDictionary {
        var dict = NSMutableDictionary()
        dict.setValue(currentSize, forKey: DictionaryKeys.cacheSize.rawValue)
        dict.setValue(requestCaches, forKey: DictionaryKeys.requestsFilenameArray.rawValue)
        return NSDictionary(dictionary: dict)
    }

    func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) -> Bool {
        var success = false
        let path = diskPathForRequest(request)?.path
        if let path = path {
            let data = NSKeyedArchiver.archivedDataWithRootObject(cachedResponse)
            currentSize += data.length
            // TODO: Cleanup how we get the hash vs. the full path
            let hash = hashForURLString(request.URL.absoluteString!)!
            var index = -1
            for i in 0..<requestCaches.count {
                if requestCaches[i] == hash {
                    index = i
                    break
                }
            }
            if index != -1 {
                requestCaches.removeAtIndex(index)
            }
            requestCaches.append(hash)
            trimCacheIfNeeded()
            persistPropertiesToDisk()
            success = data.writeToFile(path, atomically: false)
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
        @method diskPathForPropertyList
        @abstract diskPathForPropertyList will get the path
        to the property list associated with this diskCache.
        It is stored in the same directory as the cached
        request files.
    */
    func diskPathForPropertyList() -> NSURL? {
        var url: NSURL?
        let filename = "diskCacheInfo.plist"
        if let baseURL = diskPath() {
            url = NSURL(string: filename, relativeToURL: baseURL)
        }
        return url
    }

    func diskPathForRequestCacheNamed(name: String) -> NSURL? {
        var url: NSURL?
        if let baseURL = diskPath() {
            url = NSURL(string: name, relativeToURL: baseURL)
        }
        return url
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
            if let baseURL = diskPath() {
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
