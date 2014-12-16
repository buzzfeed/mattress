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
import UIKit

class DiskCache {
    /**
        Keys used to store properties in the plist.
    */
    enum DictionaryKeys: String {
        case maxCacheSize = "maxCacheSize"
        case requestsFilenameArray = "requestsFilenameArray"
    }

    // MARK: - Properties
    var isAtLeastiOS8: Bool {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var value: Bool = false
        }
        dispatch_once(&Static.onceToken) {
            Static.value = (UIDevice.currentDevice().systemVersion as NSString).doubleValue >= 8.0
        }
        return Static.value
    }

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
            if isAtLeastiOS8 {
                success = saveObject(cachedResponse, withHash: hash)
            } else {
                success = storeCachedResponsePieces(cachedResponse, withHash: hash)
            }
        }
        return success
    }

    /**
        This will store components of the NSCachedURLResponse to disk each
        individually to work around iOS 7 not properly storing the response
        to disk with it's data and userInfo.
    
        NOTE: Storage policy is not stored because it is irrelevant to offline
        cached responses.

        :param: cachedResponse an NSCachedURLResponse to persist to disk.
        :param: hash The hash associated with the NSCachedURLResponse.

        :returns: A Bool representing whether or not we successfully
            stored the response to disk.
    */
    func storeCachedResponsePieces(cachedResponse: NSCachedURLResponse, withHash hash: String) -> Bool {
        var success = true
        let responseHash = hashForResponseFromHash(hash)
        success = success && saveObject(cachedResponse.response, withHash: responseHash)
        let dataHash = hashForDataFromHash(hash)
        success = success && saveObject(cachedResponse.data, withHash: dataHash)
        if let userInfo = cachedResponse.userInfo {
            if !userInfo.isEmpty {
                let userInfoHash = hashForUserInfoFromHash(hash)
                success = success && saveObject(userInfo, withHash: userInfoHash)
            }
        }
        return success
    }

    /**
        Saves an archived object's data to disk with the hash it
        should be associated with. This will only store the request
        if it could fit in our max cache size, and will empty out
        older cached items if it needs to to make room.
    
        :param: data The data of the archived root object.
        :param: hash The hash associated with that object.
    
        :returns: A Bool indicating that the saves were successful.
    */
    func saveObject(object: NSCoding, withHash hash: String) -> Bool {
        var success = false
        let data = NSKeyedArchiver.archivedDataWithRootObject(object)
        if let path = diskPathForRequestCacheNamed(hash)?.path {
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
            if isAtLeastiOS8 {
                response = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? NSCachedURLResponse
            } else {
                response = cachedResponseFromPiecesForRequest(request)
            }
        }
        return response
    }

    /**
        Will create the cachedResponse from its response, data and
        userInfo. This is only used to workaround the bug in iOS 7
        preventing us from just saving the cachedResponse itself.
    */
    func cachedResponseFromPiecesForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        var cachedResponse: NSCachedURLResponse? = nil
        var response: NSURLResponse? = nil
        var data: NSData? = nil
        var userInfo: [NSObject : AnyObject]? = nil

        if let basePath = diskPathForRequest(request)?.path {
            let responsePath = hashForResponseFromHash(basePath)
            response = NSKeyedUnarchiver.unarchiveObjectWithFile(responsePath) as? NSURLResponse
            let dataPath = hashForDataFromHash(basePath)
            data = NSKeyedUnarchiver.unarchiveObjectWithFile(dataPath) as? NSData
            let userInfoPath = hashForUserInfoFromHash(basePath)
            userInfo = NSKeyedUnarchiver.unarchiveObjectWithFile(userInfoPath) as? [NSObject : AnyObject]
        }

        if let response = response {
            if let data = data {
                cachedResponse = NSCachedURLResponse(response: response, data: data, userInfo: userInfo, storagePolicy: .Allowed)
            }
        }

        return cachedResponse
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
        a given NSURLRequest.
    */
    func hashForRequest(request: NSURLRequest) -> String? {
        if let urlString = request.URL.absoluteString {
            return hashForURLString(urlString)
        }
        return nil
    }

    /**
        Returns the hash/filename for the response associated with
        the hash for a request. This is only used as an iOS 7
        workaround.
    */
    func hashForResponseFromHash(hash: String) -> String {
        return "\(hash)_response"
    }

    /**
        Returns the hash/filename for the data associated with
        the hash for a request. This is only used as an iOS 7
        workaround.
    */
    func hashForDataFromHash(hash: String) -> String {
        return "\(hash)_data"
    }

    /**
        Returns the hash/filename for the userInfo associated with
        the hash for a request. This is only used as an iOS 7
        workaround.
    */
    func hashForUserInfoFromHash(hash: String) -> String {
        return "\(hash)_userInfo"
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
