//
//  ViewController.swift
//  MattressExample
//
//  Created by Kevin Lord on 11/13/15.
//  Copyright © 2015 BuzzFeed. All rights reserved.
//

import UIKit
import Mattress

class ViewController: UIViewController {

    @IBOutlet var webView: UIWebView!
    let urlToCache = NSURL(string: "https://www.google.com")

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func cachePage() {
        NSLog("Caching page")
        if let
            cache = NSURLCache.sharedURLCache() as? Mattress.URLCache,
            urlToCache = urlToCache
        {
            cache.diskCacheURL(urlToCache, loadedHandler: { (webView) -> (Bool) in
                    let state = webView.stringByEvaluatingJavaScriptFromString("document.readyState")
                    if state == "complete" {
                        // Loading is done once we've returned true
                        return true
                    }
                    return false
                }, completeHandler: { () -> Void in
                    NSLog("Finished caching")
                }, failureHandler: { (error) -> Void in
                    NSLog("Error caching: %@", error)
            })
        }
    }

    @IBAction func loadPage() {
        if let urlToCache = urlToCache {
            let request = NSURLRequest(URL: urlToCache)
            webView.loadRequest(request)
        }
    }
}

