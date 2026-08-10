//
//  URLRequest+UA.swift
//  claw
//
//  Created by Zachary Gorak on 10/1/22.
//

import Foundation
import UIKit

import MachO

extension UIDevice {
    var modelIdentifier: String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulatorModelIdentifier }
        var sysinfo = utsname()
        uname(&sysinfo) // ignore return value
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
    }
}

private enum UserAgentCache {
    static let task = Task { @MainActor in
        // per @pushcx
        // $APP_NAME/$VERSION ($ARCH; $OS; +https://contact.link/for/the/app)
        let app_name = Bundle.main.name
        var version = Bundle.main.shortVersion
        #if DEBUG
        version = version + "-DEBUG"
        #endif
        let help_url = "https://zac.gorak.us/ios"

        return "\(app_name)/\(version) (\(UIDevice.current.modelIdentifier); \(UIDevice.current.systemName) \(UIDevice.current.systemVersion); +\(help_url))"
    }
}

public extension URLRequest {
    mutating func setUserAgent() async {
        setValue(await UserAgentCache.task.value, forHTTPHeaderField: "User-Agent")
    }
}
