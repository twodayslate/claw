import SwiftUI

/// The visible discussion is a sequence of rows, not a tree of lazy containers.
/// Indentation is local to the page; discussion depth is retained for colors.
struct CommentThreadRow: Identifiable {
    let comment: Comment
    let continuation: CommentStructure?
    let indentLevel: Int
    let commentDepth: Int
    var continuesThread: Bool { continuation != nil }
    var id: String { comment.id }
}

struct CommentExpansionState {
    private(set) var collapsedIDs: Set<String> = []

    subscript(expanded id: String) -> Bool {
        get { !collapsedIDs.contains(id) }
        set {
            if newValue { collapsedIDs.remove(id) }
            else { collapsedIDs.insert(id) }
        }
    }
}

enum CommentThreadLayout {
    static func maximumIndentLevel(width: CGFloat, minimumReadingWidth: CGFloat = 280) -> Int {
        // Each reply adds 20 points leading and 4 trailing, plus 32 at the root.
        // Always expose at least one reply so continuation pages make progress.
        max(1, Int((width - 32 - minimumReadingWidth) / 24))
    }

    static func rows(
        for roots: [CommentStructure],
        rootDepth: Int = 0,
        maximumIndentLevel: Int,
        collapsedIDs: Set<String> = []
    ) -> [CommentThreadRow] {
        var result: [CommentThreadRow] = []
        func append(_ nodes: [CommentStructure], indentLevel: Int) {
            for node in nodes {
                let expanded = !collapsedIDs.contains(node.id)
                let continues = expanded && !node.children.isEmpty && indentLevel >= maximumIndentLevel
                result.append(CommentThreadRow(comment: node.comment, continuation: continues ? node : nil,
                    indentLevel: indentLevel, commentDepth: rootDepth + indentLevel))
                if expanded && !continues {
                    append(node.children, indentLevel: indentLevel + 1)
                }
            }
        }
        append(roots, indentLevel: 0)
        return result
    }
}

public struct HierarchyList<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let data: [CommentStructure]
    let header: (Comment) -> HeaderContent
    let rowContent: (Comment) -> RowContent
    var highlightedCommentID: String? = nil
    var rootDepth: Int = 0
    @State private var sharedComment: Comment?
    @State private var expansion = CommentExpansionState()
    @State private var maximumIndentLevel = 3
    @ScaledMetric(relativeTo: .body) private var minimumReadingWidth: CGFloat = 280

    public var body: some View {
        let rows = CommentThreadLayout.rows(for: data, rootDepth: rootDepth,
            maximumIndentLevel: maximumIndentLevel, collapsedIDs: expansion.collapsedIDs)
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                CommentThreadRowView(row: row, header: header, rowContent: rowContent,
                    highlighted: row.id == highlightedCommentID,
                    isExpanded: $expansion[expanded: row.id], sharedComment: $sharedComment)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: Int.self) { geometry in
            CommentThreadLayout.maximumIndentLevel(width: geometry.size.width,
                minimumReadingWidth: minimumReadingWidth)
        } action: { limit in
            maximumIndentLevel = limit
        }
        .sheet(item: $sharedComment) { comment in
            ShareSheet(activityItems: [URL(string: comment.short_id_url)!])
        }
    }
}

private struct CommentThreadView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let parent: CommentStructure
    let parentDepth: Int
    let header: (Comment) -> HeaderContent
    let rowContent: (Comment) -> RowContent

    var body: some View {
        ScrollView {
            HierarchyList(data: [parent], header: header, rowContent: rowContent, rootDepth: parentDepth)
                .padding(.bottom)
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CommentThreadRowView<RowContent, HeaderContent>: View where RowContent: View, HeaderContent: View {
    let row: CommentThreadRow
    let header: (Comment) -> HeaderContent
    let rowContent: (Comment) -> RowContent
    let highlighted: Bool
    @Binding var isExpanded: Bool
    @Binding var sharedComment: Comment?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if highlighted {
                Text("Linked comment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.top, .leading])
            }
            HStack {
                header(row.comment).padding(.leading)
                Button(action: toggleExpanded) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded ? .zero : .degrees(-90))
                }
                .accessibilityLabel(isExpanded ? Text("Collapse comment") : Text("Expand comment"))
                .accessibilityIdentifier("toggle-comment-\(row.id)")
            }
            .padding(.vertical)
            if isExpanded {
                rowContent(row.comment)
                    .padding([.leading, .bottom])
                if let parent = row.continuation {
                    NavigationLink {
                        CommentThreadView(parent: parent, parentDepth: row.commentDepth,
                            header: header, rowContent: rowContent)
                    } label: {
                        Label("Continue thread", systemImage: "arrow.turn.down.right")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .padding([.leading, .bottom])
                    .accessibilityHint("Opens the replies with less indentation")
                    .accessibilityIdentifier("continue-thread-\(row.id)")
                }
            }
            Divider().padding(.leading)
        }
        .padding(.leading, CGFloat(row.indentLevel) * 20)
        .padding(.trailing, 16 + CGFloat(row.indentLevel) * 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .leading) {
            CommentIndentGuides(indentLevel: row.indentLevel,
                rootDepth: row.commentDepth - row.indentLevel)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                sharedComment = row.comment
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(action: toggleExpanded) {
                Label(isExpanded ? "Collapse" : "Expand",
                    systemImage: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
            }
        }
        .onTapGesture(perform: toggleExpanded)
    }

    private func toggleExpanded() {
        withAnimation { isExpanded.toggle() }
    }
}

/// Each row draws its ancestors' guides without measuring or wrapping descendants.
private struct CommentIndentGuides: View {
    let indentLevel: Int
    let rootDepth: Int
    @Environment(Settings.self) private var settings

    var body: some View {
        let colors = settings.commentColorScheme.colors
        ZStack(alignment: .leading) {
            ForEach(0..<indentLevel, id: \.self) { level in
                Rectangle()
                    .fill(colors.isEmpty ? Color.accentColor : colors[(rootDepth + level) % colors.count])
                    .frame(width: 3)
                    .padding(.leading, 16 + CGFloat(level) * 20)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
