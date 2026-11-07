import SwiftUI

// From https://fivestars.blog/code/swiftui-hierarchy-list.html

enum CommentThreadLayout {
    static func maximumIndentLevel(width: CGFloat, minimumReadingWidth: CGFloat = 280) -> Int {
        // Each reply adds 20 points leading and 4 trailing, plus 32 at the root.
        // Always expose at least one reply so continuation pages make progress.
        max(1, Int((width - 32 - minimumReadingWidth) / 24))
    }
}

public struct HierarchyList<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    
    let data: [CommentStructure]
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    var highlightedCommentID: String? = nil
    @State var sharedComment: Comment?
    @State private var availableWidth: CGFloat = 390
    @ScaledMetric(relativeTo: .body) private var minimumReadingWidth: CGFloat = 280
    
    public var body: some View {
        // this should be a LazyVStack but there is a bug
        // https://developer.apple.com/forums/thread/658199
        LazyVStack(alignment: .leading, spacing: 0) {
            RecursiveView(data: data, header: header, rowContent: rowContent, indentLevel: 0, maximumIndentLevel: CommentThreadLayout.maximumIndentLevel(width: availableWidth, minimumReadingWidth: minimumReadingWidth), highlightedCommentID: highlightedCommentID, sharedComment: $sharedComment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            availableWidth = width
        }
        .sheet(item: $sharedComment, content: { item in
            ShareSheet(activityItems: [URL(string: item.short_id_url)!])
        })
    }
}

private struct CommentThreadView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let parent: CommentStructure
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent

    var body: some View {
        ScrollView {
            // Keep the parent for context and restart indentation for its replies.
            HierarchyList(data: [parent], header: header, rowContent: rowContent)
                .padding(.bottom)
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RecursiveView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let data: [CommentStructure]
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    let indentLevel: Int
    let maximumIndentLevel: Int
    let highlightedCommentID: String?
    
    @Binding var sharedComment: Comment?
    
    var body: some View {
        ForEach(data) { child in
            HierarchyCommentView(header: header, rowContent: rowContent, indentLevel: indentLevel, maximumIndentLevel: maximumIndentLevel, highlightedCommentID: highlightedCommentID, child: child, sharedComment: $sharedComment, last: child == data.last!)
        }
    }
}

struct HierarchyCommentView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    
    let header: (CommentStructure) -> HeaderContent
    let rowContent: (CommentStructure) -> RowContent
    let indentLevel: Int
    let maximumIndentLevel: Int
    let highlightedCommentID: String?
    
    var child: CommentStructure

    @Environment(Settings.self) var settings
    
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
            if child.id == highlightedCommentID {
                Text("Linked comment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.top, .leading])
            }
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
                .accessibilityLabel(isExpanded ? Text("Collapse comment") : Text("Expand comment"))
                .accessibilityIdentifier("toggle-comment-\(child.id)")
            }
            .padding([.top, .bottom])
            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 0) {
                    rowContent(child)
                        .padding([.leading])
                        .padding(.bottom, child.children.isEmpty ? nil : 0.0)
                    if !child.children.isEmpty {
                        Divider().padding([.top, .leading])
                        if indentLevel >= maximumIndentLevel {
                            NavigationLink {
                                CommentThreadView(parent: child, header: header, rowContent: rowContent)
                            } label: {
                                Label("Continue thread", systemImage: "arrow.turn.down.right")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .padding(.leading)
                            .accessibilityHint("Opens the replies with less indentation")
                            .accessibilityIdentifier("continue-thread-\(child.id)")
                        } else {
                            RecursiveView(data: child.children, header: header, rowContent: rowContent, indentLevel: indentLevel+1, maximumIndentLevel: maximumIndentLevel, highlightedCommentID: highlightedCommentID, sharedComment: $sharedComment)
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
        .onTapGesture(count: 1, perform: {
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
