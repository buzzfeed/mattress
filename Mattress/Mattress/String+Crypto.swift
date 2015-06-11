//
//  String+Crypto.swift
//  Mattress
//
//  Created by Kevin Lord on 5/22/15.
//  Copyright (c) 2015 BuzzFeed. All rights reserved.
//

import Foundation

extension String {
    func MD5() -> String? {
        return (self as NSString).dataUsingEncoding(NSUTF8StringEncoding)?.MD5().hexString()
    }

    func SHA1() -> String? {
        return (self as NSString).dataUsingEncoding(NSUTF8StringEncoding)?.SHA1().hexString()
    }
}
