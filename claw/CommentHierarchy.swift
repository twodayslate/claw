import SwiftUI

// From https://fivestars.blog/code/swiftui-hierarchy-list.html

public struct HierarchyList<Data, RowContent>: View where Data: RandomAccessCollection, Data.Element: Identifiable, RowContent: View {
  private let recursiveView: RecursiveView<Data, RowContent>

    public init(data: Data, children: KeyPath<Data.Element, Data?>, header: @escaping (Data.Element) -> AnyView, rowContent: @escaping (Data.Element) -> RowContent) {
        self.recursiveView = RecursiveView(data: data, children: children, header: header, rowContent: rowContent, indentLevel: 0)
  }

  public var body: some View {
    VStack(alignment: .leading) {
      recursiveView
    }
  }
}

private struct RecursiveView<Data, RowContent>: View where Data: RandomAccessCollection, Data.Element: Identifiable, RowContent: View {
    let data: Data
    let children: KeyPath<Data.Element, Data?>
    let header: (Data.Element) -> AnyView
    let rowContent: (Data.Element) -> RowContent
    let indentLevel: Int

    var commentColor: Color {
        switch(indentLevel) {
        case 1:
            return Color.blue.opacity(0.5)
        case 2:
            return Color.green.opacity(0.5)
        case 3:
            return Color.orange.opacity(0.5)
        case 4:
            return Color.pink.opacity(0.5)
        case 5:
            return Color.red.opacity(0.5)
        case 6:
            return Color.yellow.opacity(0.5)
        case 7:
            return Color.purple.opacity(0.5)
        default:
            return Color.accentColor.opacity(0.5)
        }
    }
    
  var body: some View {
    ForEach(data) { child in
        VStack(alignment: .leading) {
            FSDisclosureGroup {
                VStack(alignment: .leading) {
                    rowContent(child)
                    if let subChildren = child[keyPath: children] {
                        VStack(alignment: .leading) {
                            RecursiveView(data: subChildren, children: children, header: header, rowContent: rowContent, indentLevel: indentLevel+1)
                        }.padding([.leading], 16.0).overlay(RoundedRectangle(cornerRadius: 8.0).foregroundColor(self.commentColor).frame(width: 3, alignment: .leading), alignment: .leading)
                    }
                }
            } label: {
                header(child)
            }
        }
    }
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
