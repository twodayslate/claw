import SwiftUI

struct SelectedTagsView: View {
    @State var tags: [String] = UserDefaults.standard.object(forKey: "selectedTags") as? [String] ?? ["programming"] {
        didSet {
            UserDefaults.standard.set(self.tags, forKey: "selectedTags")
        }
    }

    var body: some View {
        let wrapper = TagStoryView(tags: self.tags)
        
        wrapper//.id(self.tags)
            .navigationBarItems(
                leading: NavigationLink(
                    destination: SelectTagsView(tags: $tags)
                        .navigationBarTitle("Selected Tags", displayMode: .inline),
                    label: {
                        Text("Edit").bold()
                    }
                )
            )
    }
}
