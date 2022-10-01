import SwiftUI

struct TagView: View {
    var tag: String
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: Settings
    
    var color: Color {
        if tag == "ask" || tag == "show" || tag == "announce" || tag == "interview" {
            return Color(UIColor.systemRed.lighter(by: 0.5))
        }
        if tag == "video" || tag == "audio" || tag == "pdf" || tag == "slides" || tag == "transcript" {
            return Color(UIColor.systemBlue.lighter(by: 0.5))
        }
        if tag == "meta" {
            return Color(UIColor.systemGray.lighter(by: 0.5))
        }
        return Color(UIColor.systemYellow.lighter(by: 0.5))
    }
    
    var foregroundColor: Color {
        return Color(UIColor.darkText)
    }
    
    var body:some View {
        SGNavigationLink(
            destination: TagStoryView(tags: [tag]),
            title: tag,
            withChevron: false) {
                Text(tag)
                    .font(Font(.footnote, sizeModifier: CGFloat(settings.textSizeModifier)))
                    .fixedSize(horizontal: true, vertical: false)
                    .lineLimit(1)
                    .foregroundColor(foregroundColor)
                    .padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0))
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.9), strokeBorder: Color(UIColor.opaqueSeparator), lineWidth: 1)
                    }
            }
    }
}

/// https://www.hackingwithswift.com/quick-start/swiftui/how-to-fill-and-stroke-shapes-at-the-same-time
extension Shape {
    func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: Double = 1) -> some View {
        self
            .stroke(strokeStyle, lineWidth: lineWidth)
            .background(self.fill(fillStyle))
    }
}

/// https://www.hackingwithswift.com/quick-start/swiftui/how-to-fill-and-stroke-shapes-at-the-same-time
extension InsettableShape {
    func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: Double = 1) -> some View {
        self
            .strokeBorder(strokeStyle, lineWidth: lineWidth)
            .background(self.fill(fillStyle))
    }
}

// TODO: generate tag list
// /tags.json
// /t/<tag>.json

struct TagList: View {
    var tags: [String]
    
    @State private var scrollViewSize: CGSize = .zero
    @State private var contentSize: CGSize = .zero
    
    private let scrollPadding = 3.0
    
    var body: some View {
        ScrollView(shouldScroll ? .horizontal : [], showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(tags, id: \.self) { tag in
                    TagView(tag: tag)
                }
            }
            .readSize($contentSize)
            .padding(.horizontal, shouldScroll ? scrollPadding : 0)
        }
        .readSize($scrollViewSize)
        .frame(height: contentSize.height)
        .mask {
            if shouldScroll {
                GeometryReader { reader in
                    let gradientSize = scrollPadding / max(10, reader.size.width)
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black, location: gradientSize),
                            .init(color: .black, location: 1.0 - gradientSize),
                            .init(color: .black.opacity(0.0), location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            } else {
                Color.black
            }
        }
    }
    
    private var shouldScroll: Bool {
        scrollViewSize.width <= contentSize.width
    }
}

/// See https://stackoverflow.com/a/69781817
struct SizeReaderModifier: ViewModifier  {
    @Binding var size: CGSize
    
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry -> Color in
                DispatchQueue.main.async {
                    size = geometry.size
                }
                return Color.clear
            }
        )
    }
}

extension View {
    func readSize(_ size: Binding<CGSize>) -> some View {
        self.modifier(SizeReaderModifier(size: size))
    }
}

struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TagView(tag: "ios")
                .padding()
            TagList(tags: ["programming", "philosophy", "video", "ask", "meta"])
                .frame(width: 200, alignment: .leading)
                .padding()
            ZStack {
                TagList(tags: ["show", "ios", "video", "ask", "meta"])
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .environment(\.colorScheme, .dark)
        }
        .previewLayout(.sizeThatFits)
        .environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
    }
}
