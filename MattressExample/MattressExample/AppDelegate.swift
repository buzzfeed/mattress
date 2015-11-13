//
//  AppDelegate.swift
//  MattressExample
//
//  Created by Kevin Lord on 11/13/15.
//  Copyright © 2015 BuzzFeed. All rights reserved.
//

import UIKit
import Mattress

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let kB = 1024
        let MB = 1024 * kB
        let GB = 1024 * MB
        let isOfflineHandler: (() -> Bool) = {
            /*
                We are returning true here for demo purposes only.
                You should use Reachability or another method for determining whether the user is
                offline and return the appropriate value
            */
            return true
        }
        let urlCache = Mattress.URLCache(memoryCapacity: 20 * MB, diskCapacity: 20 * MB, diskPath: nil,
            mattressDiskCapacity: 1 * GB, mattressDiskPath: nil, mattressSearchPathDirectory: .DocumentDirectory,
            isOfflineHandler: isOfflineHandler)

        NSURLCache.setSharedURLCache(urlCache)
        return true
    }
}

