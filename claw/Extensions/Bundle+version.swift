//
//  Bundle+version.swift
//  claw
//
//  Created by Zachary Gorak on 10/14/22.
//

import Foundation

extension Bundle {
    /// CFBundleName
    var name: String {
        object(forInfoDictionaryKey: "CFBundleName") as! String
    }
    
    /// CFBundleShortVersionString
    ///
    /// Example: 1.2.0
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    /// CFBundleShortVersionString-CFBundleVersion
    /// Example: 1.2.0-4
    var longVersion: String {
        shortVersion + "-" + (object(forInfoDictionaryKey:"CFBundleVersion") as! String)
    }
}
