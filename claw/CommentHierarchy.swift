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
        LazyVStack(alignment: .leading, spacing: 0) {
            RecursiveView(data: data, header: header, rowContent: rowContent, indentLevel: 0, sharedComment: $sharedComment)
        }
        .sheet(item: $sharedComment, content: { item in
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

    @EnvironmentObject var settings: Settings
    
    @Binding var sharedComment: Comment?
    
    @State var showShareSheet = false
    
    var last = false
    
    var commentColor: Color {
        let index = indentLevel % 7
        if settings.commentColorScheme.colors.count < index {
            return .accentColor
        }
        return settings.commentColorScheme.colors[index]
    }
    
    @State var isExpanded: Bool = true
    
    @State var backgroundColorState = Color(UIColor.systemBackground)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header(child).padding([.leading])
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded ? .zero : .degrees(-90))
                }
            }
            .padding([.top, .bottom])
            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 0) {
                    rowContent(child)
                        .padding([.leading])
                        .padding(.bottom, child.children.isEmpty ? nil : 0.0)
                    if !child.children.isEmpty {
                        Divider().padding([.top, .leading])
                        RecursiveView(data: child.children, header: header, rowContent: rowContent, indentLevel: indentLevel+1, sharedComment: $sharedComment)
                            .padding([.leading], 4)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8.0)
                                    .foregroundColor(self.commentColor)
                                    .frame(width: 3, alignment: .leading)
                                    .padding([.top, .bottom], 8.0)
                            }
                            .padding([.leading], 16)
                    }
                }
                .padding(indentLevel > 0 ? [.trailing] : [], 4.0)
            }
            if !last {
                Divider().padding([.horizontal])
            }
        }
        .padding(indentLevel == 0 ? [.trailing] : [])
        .background(backgroundColorState.edgesIgnoringSafeArea(.all))
        .contextMenu(menuItems: {
            Button(action: {
                sharedComment = child.comment
            }, label: {
                Label("Share", systemImage: "square.and.arrow.up")
            })
            Button(action: {
                withAnimation(.easeIn) {
                    isExpanded.toggle()
                }
            }, label: {Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")})
        })
        .onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
            withAnimation(.easeIn) {
                backgroundColorState = Color(UIColor.systemGray4)
                withAnimation(.easeOut) {
                    backgroundColorState = Color(UIColor.systemBackground)
                    isExpanded.toggle()
                }
            }
        })
    }
}
