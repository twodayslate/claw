import Foundation
import SwiftUI

public class ObservableURL: ObservableObject {
    @Published var url: URL? = nil
}
