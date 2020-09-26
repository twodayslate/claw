//
//  SafariActivity.swift
//  claw
//
//  Created by Zachary Gorak on 9/22/20.
//

import Foundation
import UIKit

/**
 An Open in Safari action for URLs
 */
class SafariActivity: UIActivity {
    override var activityImage: UIImage? {
        let largeConfig = UIImage.SymbolConfiguration(scale: .large)
        return UIImage(systemName: "safari", withConfiguration: largeConfig)
    }
    
    override var activityTitle: String? {
        return "Open in Safari"
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if let url = item as? URL, UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }
    
    var urls = [URL]()
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if let url = item as? URL, UIApplication.shared.canOpenURL(url) {
                urls.append(url)
            }
        }
    }
    
    override func perform() {
        guard let url = urls.first else {
            self.activityDidFinish(false)
            return
        }
        
        UIApplication.shared.open(url, completionHandler: { status in
            self.activityDidFinish(status)
        })
    }
}
