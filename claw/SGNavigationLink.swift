// https://stackoverflow.com/a/57869749/193772
import SwiftUI

// Note: chevron appears in lists
struct SGNavigationLink<Content, Destination>: View where Destination: View, Content: View {
    let destination:Destination?
    let content: () -> Content
    let withChevron: Bool
    
    @State private var isLinkActive:Bool = false
    
    init(destination: Destination, title: String = "", withChevron: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.withChevron = withChevron
        self.content = content
        self.destination = destination
    }
    
    var body: some View {
        // Need the ZStack so the navigation link can expand the whole cell
        ZStack(alignment: .leading) {
            navigationLink
            content()
        }
        .onTapGesture {
            self.pushHiddenNavLink()
        }
    }
    
    @ViewBuilder var navigationLink: some View {
        if self.withChevron {
            NavigationLink(destination: destination, isActive: $isLinkActive){
                Color.clear
            }
        } else {
            NavigationLink(destination: destination, isActive: $isLinkActive){
                EmptyView()
            }.hidden()
        }
    }
    
    func pushHiddenNavLink(){
        self.isLinkActive = true
    }
}

struct SGNavigationLink_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                List {
                    SGNavigationLink(destination: Text("Hello World")) {
                        Text("Button with Chevron")
                    }
                }
            }
            NavigationView {
                List {
                    SGNavigationLink(destination: Text("Hello World"), withChevron: false) {
                        Text("Button without Chevron")
                    }
                }
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
