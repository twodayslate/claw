import SwiftUI

struct TagView: View {
    var tag: String
    
    var body:some View {
        Text(tag).font(.footnote).lineLimit(1).minimumScaleFactor(0.5).foregroundColor(.black).padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 8.0)).background(Color.yellow).overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color.secondary, lineWidth: 2.0)
        ).clipShape(RoundedRectangle(cornerRadius: 8.0))
    }
}

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
            TagList(tags: ["programming", "philosophy", "video"])
        }.previewLayout(.sizeThatFits)
    }
}
