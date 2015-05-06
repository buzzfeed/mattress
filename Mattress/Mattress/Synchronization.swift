//
//  Synchronization.swift
//  Mattress
//
//  Created by Jaim Zuber on 3/27/15.
//  Copyright (c) 2015 BuzzFeed. All rights reserved.
//

import Foundation

func synchronized<T>(lockObj: AnyObject!, closure: () -> T) -> T {
    objc_sync_enter(lockObj)
    var value: T = closure()
    objc_sync_exit(lockObj)
    return value
}
