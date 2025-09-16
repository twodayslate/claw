import SwiftUI

@Observable
class SelectedTagsModel {
    var tags: [String] {
        didSet {
            UserDefaults.standard.set(self.tags, forKey: "selectedTags")
        }
    }

    init() {
        self.tags = UserDefaults.standard.object(forKey: "selectedTags") as? [String] ?? ["programming"]
    }
}

struct SelectedTagsView: View {
    @State var model = SelectedTagsModel()

    @State var editMode: EditMode = .inactive

    var body: some View {
        Group {
            if editMode == .active {
                SelectTagsView(tags: $model.tags)
            } else {
                TagStoryView(tags: model.tags)
            }
        }
        .animation(.default, value: editMode)
        .navigationTitle(model.tags.joined(separator: ", "))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
    }
}
