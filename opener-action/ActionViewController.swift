//
//  ActionViewController.swift
//  opener-action
//
//  Created by Zachary Gorak on 10/25/20.
//

import UIKit
import MobileCoreServices

class ActionViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Get the item[s] we're handling from the extension context.
        
        // For example, look for an image and place it into an image view.
        // Replace this with something appropriate for the type[s] your extension supports.
        
        for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
            if let attachments = item.attachments {
                for itemProvider in attachments {
                    if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                        
                        itemProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { result, _  in
                            if let url = result as? URL {
                                print("got an url", url)
                                self.openUrl(url: URL(string: "claw://open?url=\(url.absoluteString)")!)
                                return
                            }
                        })
                     }
                }
            }
        }
    }
    
    func openUrl(url: URL?) {
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let r = responder, !r.responds(to: selector) {
            responder = r.next
        }
        _ = responder?.perform(selector, with: url)
        self.done()
    }

    func canOpenUrl(url: URL?) -> Bool {
        let selector = sel_registerName("canOpenURL:")
        var responder: UIResponder? = self
        while let r = responder, !r.responds(to: selector) {
            responder = r.next
        }
        return (responder!.perform(selector, with: url) != nil)
    }

    @IBAction func done() {
        // Return any edited content to the host app.
        // This template doesn't do anything, so we just echo the passed in items.
        self.extensionContext?.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }

}
