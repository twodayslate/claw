// https://stackoverflow.com/a/57869749/193772
import SwiftUI

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
        return ZStack (alignment: .leading){
            if self.withChevron {
                ZStack(alignment: .leading) {
                    NavigationLink(destination: destination, isActive: $isLinkActive){
                        Color.clear
                    }
                    content()
                }
            } else {
                NavigationLink(destination: destination, isActive: $isLinkActive){
                        EmptyView()
                }.hidden()
                content()
            }
        }
        .onTapGesture {
            self.pushHiddenNavLink()
        }
    }

    func pushHiddenNavLink(){
        self.isLinkActive = true
    }
}

struct SGNavigationLink_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SGNavigationLink(destination: Text("Hello World")) {
                Text("Button with Chevron")
            }
            SGNavigationLink(destination: Text("Hello World"), withChevron: false) {
                Text("Button without Chevron")
            }
        }.previewLayout(.sizeThatFits)
        
    }
}
