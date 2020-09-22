import SwiftUI



struct TagView: View {
    var tag: String
    
    @Environment(\.colorScheme) var colorScheme
    
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
        Text(tag).font(.footnote).lineLimit(1).minimumScaleFactor(0.5).foregroundColor(foregroundColor).padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0)).background(color).overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color(UIColor.separator), lineWidth: 2.0)
        ).clipShape(RoundedRectangle(cornerRadius: 8.0))
    }
}

// TODO: generate tag list
// /tags.json
// /t/<tag>.json

struct TagList: View {
    var tags: [String]
    var body: some View {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    TagView(tag: tag)
                }
            }
    }
}

struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TagView(tag: "apple")
            TagList(tags: ["programming", "philosophy", "video", "ask", "meta"])
            ZStack {
                TagList(tags: ["show", "apple", "video", "ask", "meta"])
            }.background(Color(UIColor.systemBackground)).environment(\.colorScheme, .dark)
        }.previewLayout(.sizeThatFits)
    }
}
