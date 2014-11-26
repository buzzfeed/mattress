//
//  DiskCache.swift
//  Mattress
//
//  Created by David Mauro on 11/12/14.
//  Copyright (c) 2014 BuzzFeed. All rights reserved.
//

/**
    DiskCache is a NSURLCache replacement that will store
    and retreive NSCachedURLResponses to disk.
*/

import Foundation

class DiskCache {
    /**
        Keys used to store properties in the plist.
    */
    enum DictionaryKeys: String {
        case maxCacheSize = "maxCacheSize"
        case requestsFilenameArray = "requestsFilenameArray"
    }

    // MARK: - Properties

    let path: String
    let searchPathDirectory: NSSearchPathDirectory
    let maxCacheSize: Int
    var currentSize = 0
    var requestCaches: [String] = []

    // Mark: - Instance methods

    /**
        Initializes a new DiskCache
    
        :param: path The path of the location on disk that should be used
            to store requests.
        :param: searchPathDirectory The NSSearchPathDirectory that should be
            used to find the location at which to store requests.
        :param: maxCacheSize The size limit of this diskCache. When the size
            of the requests exceeds this amount, older requests will be removed.
            No requests that are larger than this size will even attempt to be
            stored.
    */
    init(path: String?, searchPathDirectory: NSSearchPathDirectory, maxCacheSize: Int) {
        self.path = path ?? "offline"
        self.searchPathDirectory = searchPathDirectory
        self.maxCacheSize = maxCacheSize
        loadPropertiesFromDisk()
    }

    /**
        Load appropriate properties from the plist to restore
        this cache from disk.
    */
    func loadPropertiesFromDisk() {
        if let plistPath = diskPathForPropertyList()?.path {
            if !NSFileManager.defaultManager().fileExistsAtPath(plistPath) {
                persistPropertiesToDisk()
            } else {
                if let dict = NSDictionary(contentsOfFile: plistPath) {
                    if let currentSize = dict.valueForKey(DictionaryKeys.maxCacheSize.rawValue) as? Int {
                        self.currentSize = currentSize
                    }
                    if let requestCaches = dict.valueForKey(DictionaryKeys.requestsFilenameArray.rawValue) as? [String] {
                        self.requestCaches = requestCaches
                    }
                }
            }
        }
    }

    /**
        Save appropriate properties to a plist to save
        this cache to disk.
    */
    func persistPropertiesToDisk() {
        if let plistPath = diskPathForPropertyList()?.path {
            let dict = dictionaryForCache()
            dict.writeToFile(plistPath, atomically: true)
        }
    }

    /**
        This will keep removing the oldest request until our
        currentSize is not greater than the maxCacheSize.
    */
    func trimCacheIfNeeded() {
        while currentSize > maxCacheSize && !requestCaches.isEmpty {
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

    /**
        Create an NSDictionary that will be used to store
        this diskCache's properties to disk.
    */
    func dictionaryForCache() -> NSDictionary {
        var dict = NSMutableDictionary()
        dict.setValue(currentSize, forKey: DictionaryKeys.maxCacheSize.rawValue)
        dict.setValue(requestCaches, forKey: DictionaryKeys.requestsFilenameArray.rawValue)
        return NSDictionary(dictionary: dict)
    }

    /**
        storeCachedResponse:forRequest: functions much like NSURLCache's
        similarly named method, storing a response and request to disk only.
    
        :param: cachedResponse an NSCachedURLResponse to persist to disk.
        :param: forRequest an NSURLRequest to associate the cachedResponse with.
    
        :returns: A Bool representing whether or not we successfully
            stored the response to disk.
    */
    func storeCachedResponse(cachedResponse: NSCachedURLResponse, forRequest request: NSURLRequest) -> Bool {
        var success = false
        if let hash = hashForRequest(request) {
            if let path = diskPathForRequestCacheNamed(hash)?.path {
                let data = NSKeyedArchiver.archivedDataWithRootObject(cachedResponse)
                if data.length < maxCacheSize {
                    currentSize += data.length
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
            }
        }
        return success
    }

    /**
        cachedResponseForRequest: functions much like NSURLCache's
        method of the same signature. An NSCachedURLResponse associated
        with the specified NSURLRequest will be returned.
    */
    func cachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        var response: NSCachedURLResponse?
        if let path = diskPathForRequest(request)?.path {
            response = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? NSCachedURLResponse
        }
        return response
    }

    /**
        hasCacheForRequest: returns a Bool indicating whether
        this diskCache has a cachedResponse associated with the
        specified NSURLRequest.
    */
    func hasCacheForRequest(request: NSURLRequest) -> Bool {
        if let hash = hashForRequest(request) {
            for requestHash in requestCaches {
                if hash == requestHash {
                    return true
                }
            }
        }
        return false
    }

    /**
        Returns the path where we should store our plist.
    */
    func diskPathForPropertyList() -> NSURL? {
        var url: NSURL?
        let filename = "diskCacheInfo.plist"
        if let baseURL = diskPath() {
            url = NSURL(string: filename, relativeToURL: baseURL)
        }
        return url
    }

    /**
        Returns the path where we should store a cache
        with the specified filename.
    */
    func diskPathForRequestCacheNamed(name: String) -> NSURL? {
        var url: NSURL?
        if let baseURL = diskPath() {
            url = NSURL(string: name, relativeToURL: baseURL)
        }
        return url
    }

    /**
        Returns the path where a response should be stored
        for a given NSURLRequest.
    */
    func diskPathForRequest(request: NSURLRequest) -> NSURL? {
        var url: NSURL?
        if let hash = hashForRequest(request) {
            if let baseURL = diskPath() {
                url = NSURL(string: hash, relativeToURL: baseURL)
            }
        }
        return url
    }

    /**
        Return the path that should be used as the baseURL for
        all paths associated with this diskCache.
    */
    func diskPath() -> NSURL? {
        var url: NSURL?
        if let baseURL = NSFileManager.defaultManager().URLForDirectory(searchPathDirectory,
            inDomain: .UserDomainMask, appropriateForURL: nil, create: false, error: nil)
        {
            url = NSURL(string: path, relativeToURL: baseURL)
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

    /**
        Returns the hash/filename that should be used for
        a give NSURLRequest.
    */
    func hashForRequest(request: NSURLRequest) -> String? {
        if let urlString = request.URL.absoluteString {
            return hashForURLString(urlString)
        }
        return nil
    }

    /**
        Returns the hash/filename that should be used for
        a given the URL absoluteString of a request.
    */
    func hashForURLString(string: String) -> String? {
        // TODO: This should probably be an MD5 hash, but I couldn't get Crypto imported properly
        let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        var out = data?.description
        out = out?.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        out = out?.stringByReplacingOccurrencesOfString("<", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        out = out?.stringByReplacingOccurrencesOfString(">", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        return out
    }
}
