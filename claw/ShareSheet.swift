import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
    
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities ?? [SafariActivity()])
        controller.excludedActivityTypes = excludedActivityTypes
        // We need to dismiss the controller otherwise we have issues with the new sheet not displaying
        // see #22
        controller.completionWithItemsHandler = { t,t1,t2,t3 in
            controller.dismiss(animated: true, completion: nil)
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to do here
    }
}
