import Foundation
import SwiftUI

public class ObservableURL: ObservableObject {
    @Published var url: URL? = nil
    
    var bindingUrl: Binding<URL?> {
        return Binding(get: {
            return self.url
        }, set: { newValue in
            self.url = newValue
        })
    }
}
