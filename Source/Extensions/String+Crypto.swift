//
//  String+Crypto.swift
//  Mattress
//
//  Created by Kevin Lord on 5/22/15.
//  Copyright (c) 2015 BuzzFeed. All rights reserved.
//

import Foundation

extension String {
    func mattress_MD5() -> String? {
        return (self as NSString).dataUsingEncoding(NSUTF8StringEncoding)?.mattress_MD5().mattress_hexString()
    }

    func mattress_SHA1() -> String? {
        return (self as NSString).dataUsingEncoding(NSUTF8StringEncoding)?.mattress_SHA1().mattress_hexString()
    }
}
