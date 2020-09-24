import SwiftUI

// From https://fivestars.blog/code/swiftui-hierarchy-list.html

public struct HierarchyList<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
  private let recursiveView: RecursiveView<RowContent, HeaderContent>

    init(data: [CommentStructure], header: @escaping (CommentStructure) -> HeaderContent, rowContent: @escaping (CommentStructure) -> RowContent) {
        self.recursiveView = RecursiveView(data: data, header: header, rowContent: rowContent, indentLevel: 0)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      recursiveView
    }
  }
}

private struct RecursiveView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let data: [CommentStructure]
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    let indentLevel: Int
    
    
  var body: some View {
    ForEach(data) { child in
        HierarchyCommentView(header: header, rowContent: rowContent, indentLevel: indentLevel, child: child, last: child == data.last)
    }
  }
}

struct HierarchyCommentView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    let indentLevel: Int
    
    var child: CommentStructure
    
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
                            RecursiveView(data: subChildren, header: header, rowContent: rowContent, indentLevel: indentLevel+1).padding([.leading], 4).overlay(RoundedRectangle(cornerRadius: 8.0).foregroundColor(self.commentColor).frame(width: 3, alignment: .leading).padding([.top], 8.0), alignment: .leading).padding([.leading], 16)
                        }
                    }
                },
                label: {
                    header(child).padding([.leading])
                }).padding([.top], 6.0).padding(indentLevel > 0 ? [.trailing] : [], 4.0)
            if !last {
                Divider().padding([.horizontal])
            }
        }.padding(indentLevel == 0 ? [.trailing] : []).background(backgroundColorState.edgesIgnoringSafeArea(.all)).contextMenu(menuItems: {
                Button(action: {
                    showShareSheet = true
                }, label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                })
                Button(action: {
                    withAnimation(.easeIn) {
                        isExpanded.toggle()
                    }
                }, label: {Label(isExpanded ? "Collapse" : "Expand", systemImage: "rectangle.expand.vertical")})
            }).sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [URL(string: child.comment.short_id_url)!])
            }.onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
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
