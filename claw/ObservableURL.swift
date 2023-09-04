import Foundation
import SwiftUI

@MainActor
public class ObservableURL: ObservableObject {
    @Published var url: URL? = nil
}
