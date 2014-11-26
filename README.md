Mattress
========
A Swift framework for storing entire web pages into an offline cache distinct from but interoperable with the standard NSURLCache layer.

**Installation**
----------------
This space left intentionally blank.

**Usage**
---------
You should create an instance of URLCache and set it as the shared
cache for your app in your application:didFinishLaunching: method.

```
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    let reach = Reachability.reachabilityForInternetConnection()
    reach.startNotifier()
    let kB = 1024
    let MB = 1024 * kB
    let GB = 1024 * MB
    let isOfflineHandler: (() -> Bool) = {
        let isOffline = reach.currentReachabilityStatus().value == NotReachable.value
        return isOffline
    }
    let urlCache = Mattress.URLCache(memoryCapacity: 20 * MB, diskCapacity: 20 * MB, diskPath: nil,
    	offlineDiskCapacity: 1 * GB, offlineDiskPath: nil, offlineSearchPathDirectory: .DocumentDirectory,
    	isOfflineHandler: isOfflineHandler)
    
    NSURLCache.setSharedURLCache(urlCache)
    return true
}
```

To cache a webPage in the offline disk cache, simply call URLCache's offlineCacheURL:loadedHandler: method.

```
if let cache = NSURLCache.sharedURLCache() as? Mattress.URLCache {
    let url = NSURL(string: "http://www.buzzfeed.com")!
    cache.offlineCacheURL(url) { [unowned self] webView in
        var state = webView.stringByEvaluatingJavaScriptFromString("document.readyState")
        if state == "complete" {
        	// Loading is done once we've returned true
            return true
        }
        return false
    }
}
```