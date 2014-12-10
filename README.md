Mattress
========
A Swift framework for storing entire web pages into an offline cache distinct from but interoperable with the standard NSURLCache layer.

**Installation**
----------------

1. Add Mattress as a [submodule](http://git-scm.com/docs/git-submodule) with `git submodule add https://github.com/buzzfeed/mattress` (ideally forking and pointing to your fork's url)
2. Open the `Mattress` folder, and drag `Mattress.xcodeproj` into the file navigator of your app project. **NOTE: The Mattress project needs to be added somewhere under the target project or you won't be able to add it to your target dependencies.**
3. Ensure that the deployment target of the Mattress project matches that of the application target.
4. In your target's "Build Phases" panel, add `Mattress.framework` to the "Target Dependencies"
5. Click on the `+` button at the top left of the panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add `Mattress.framework`.

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