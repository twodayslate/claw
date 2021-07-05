import SwiftUI

// From https://fivestars.blog/code/swiftui-hierarchy-list.html

public struct HierarchyList<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {

    let data: [CommentStructure]
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    @State var sharedComment: Comment?

    public var body: some View {
    // this should be a LazyVStack but there is a bug
    // https://developer.apple.com/forums/thread/658199
        VStack(alignment: .leading, spacing: 0) {
            RecursiveView(data: data, header: header, rowContent: rowContent, indentLevel: 0, sharedComment: $sharedComment)
        }.sheet(item: $sharedComment, content: { item in
            ShareSheet(activityItems: [URL(string: item.short_id_url)!])
        })
    }
}

private struct RecursiveView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let data: [CommentStructure]
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    let indentLevel: Int
    
    @Binding var sharedComment: Comment?
        
  var body: some View {
    ForEach(data) { child in
        HierarchyCommentView(header: header, rowContent: rowContent, indentLevel: indentLevel, child: child, sharedComment: $sharedComment, last: child == data.last!)
    }
  }
}

struct HierarchyCommentView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    let indentLevel: Int
    
    var child: CommentStructure
    
    @Binding var sharedComment: Comment?
    
    @State var showShareSheet = false
    
    var last = false
    
    var commentColor: Color {
        switch(indentLevel % 7) {
            case 0:
                return Color.blue.opacity(0.5)
            case 1:
                return Color.green.opacity(0.5)
            case 2:
                return Color.orange.opacity(0.5)
            case 3:
                return Color.pink.opacity(0.5)
            case 4:
                return Color.red.opacity(0.5)
            case 5:
                return Color.yellow.opacity(0.5)
            default:
                return Color.purple.opacity(0.5)
        }
    }
    
    @State var isExpanded: Bool = true
    
    @State var backgroundColorState = Color(UIColor.systemBackground)
    
    var body: some View {
        VStack(alignment: .leading) {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(alignment: .leading, spacing: 0) {
                        rowContent(child).padding([.leading])
                        if let subChildren = child.children {
                            Divider().padding([.top, .leading])
                            RecursiveView(data: subChildren, header: header, rowContent: rowContent, indentLevel: indentLevel+1, sharedComment: $sharedComment).padding([.leading], 4).overlay(RoundedRectangle(cornerRadius: 8.0).foregroundColor(self.commentColor).frame(width: 3, alignment: .leading).padding([.top], 8.0), alignment: .leading).padding([.leading], 10)
                        }
                    }
                },
                label: {
                    header(child).padding([.leading])
                }).padding([.top], 6.0).padding(indentLevel > 0 ? [.trailing] : [], 2.0)
            if !last {
                Divider().padding([.horizontal])
            }
        }.padding(indentLevel == 0 ? [.trailing] : []).background(backgroundColorState.edgesIgnoringSafeArea(.all)).contextMenu(menuItems: {
                // for some reason the share sheet won't display if the comment isn't
                //if indentLevel == 0  {
                    Button(action: {
                        sharedComment = child.comment
                    }, label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    })
                //}
                Button(action: {
                    withAnimation(.easeIn) {
                        isExpanded.toggle()
                    }
                }, label: {Label(isExpanded ? "Collapse" : "Expand", systemImage: "rectangle.expand.vertical")})
            }).onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
                withAnimation(.easeIn) {
                    backgroundColorState = Color(UIColor.systemGray4)
                    withAnimation(.easeOut) {
                        backgroundColorState = Color(UIColor.systemBackground)
                    }
                    isExpanded.toggle()
                }
            })
    }
}

struct FSDisclosureGroup<Label, Content>: View where Label: View, Content: View {
  @State var isExpanded: Bool = true
  var content: () -> Content
  var label: () -> Label

  var body: some View {
    DisclosureGroup(
      isExpanded: $isExpanded,
      content: content,
      label: label
    )
  }
}
