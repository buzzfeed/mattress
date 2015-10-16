Mattress
========
A Swift framework for storing entire web pages into a disk cache distinct from, but interoperable with, the standard NSURLCache layer. This is useful for both pre-caching web content for faster loading, as well as making web content available for offline browsing.

**Requirements**
----------------

- iOS 7.0+ (iOS 8 required for integration as an embedded framework)

**Installation**
----------------

Mattress includes a wrapper around CommonCrypto so that it can be easily used from within Swift. You will need to make sure you include both the Mattress and CommonCrypto frameworks in your project.

**Carthage (Recommended)**

If you are not already using Carthage, you will need to install it using [Homebrew](http://brew.sh).

```
$ brew update
$ brew install carthage
```

Once installed, add it to your Cartfile:

```
github "buzzfeed/Mattress" >= 1.0.0
```

You will then need to build using Carthage, and manually integrate both the Mattress and CommonCrypto frameworks into your project.

```
$ carthage build
```

**CocoaPods**

If you are not already using CocoaPods, you will need to install it using RubyGems.

```
$ gem install cocoapods
```

Once installed, add it to your Podfile:

```ruby
pod 'Mattress', '~> 1.0.0'
```

**Manual**

1. Open the `Mattress` folder, and drag `Mattress.xcodeproj` into the file navigator of your app project. **NOTE: The Mattress project needs to be added somewhere under the target project or you won't be able to add it to your target dependencies.**
2. Ensure that the deployment target of the Mattress project matches that of the application target.
3. In your target's "Build Phases" panel, add `Mattress.framework` to the "Target Dependencies"
4. Click on the `+` button at the top left of the panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add both `Mattress.framework` and `CommonCrypto.framework`.

**Usage**
---------
You should create an instance of URLCache and set it as the shared
cache for your app in your application:didFinishLaunching: method.

```swift
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
    	mattressDiskCapacity: 1 * GB, mattressDiskPath: nil, mattressSearchPathDirectory: .DocumentDirectory,
    	isOfflineHandler: isOfflineHandler)
    
    NSURLCache.setSharedURLCache(urlCache)
    return true
}
```

To cache a webPage in the Mattress disk cache, simply call URLCache's diskCacheURL:loadedHandler: method.

```swift
if let cache = NSURLCache.sharedURLCache() as? Mattress.URLCache {
    let url = NSURL(string: "http://www.buzzfeed.com")!
    cache.diskCacheURL(url) { [unowned self] webView in
        var state = webView.stringByEvaluatingJavaScriptFromString("document.readyState")
        if state == "complete" {
        	// Loading is done once we've returned true
            return true
        }
        return false
    }
}
```

Once cached, you can simply load the webpage in a UIWebView and it will be loaded from the Mattress cache, like magic.

**Considerations**
---------

Mattress does not work with WKWebView. The current WKWebView implementation uses its own internal system for caching and does not properly integrate with NSURLProtocol to allow Mattress to intercept requests made.

Due to Mattress' current architecture and use of web views, a good chunk of the caching work must happen on the main thread. This is obviously not a problem when caching pages while in the background, such as during a background fetch. However, it is something to be mindful of when your app is active in the foreground. We have had good luck using it this way with minimal performance impact, but your mileage may vary.


**Contributing**
----------------

Contributions are welcome. Please feel free to open a pull request. 

We also welcome feature requests and bug reports. Just open an issue.

**License**
---------

Mattress is licensed under the MIT License.
