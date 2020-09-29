import SwiftUI

struct ZZLabel: View {
    var iconBackgroundColor: Color = Color.accentColor
    var iconColor: Color = Color.white
    var systemImage: String? = nil
    var image: String? = nil
    var imageFile: String? = nil
    var text: String
    var iconScale = 0.6
    
    var body: some View {
        Label(
            title: { Text(text).foregroundColor(Color(UIColor.label)) },
            icon: { ZStack {
                Image(systemName: "app.fill").resizable().aspectRatio( contentMode: .fit).foregroundColor(self.iconBackgroundColor)
                if let path = imageFile, let uiImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: uiImage).resizable().aspectRatio( contentMode: .fit).scaleEffect(CGSize(width: iconScale, height: iconScale)).foregroundColor(self.iconColor)
                }
                else if let name = image {
                    Image(name).resizable().aspectRatio( contentMode: .fit).scaleEffect(CGSize(width: iconScale, height: iconScale)).foregroundColor(self.iconColor)
                } else {
                    Image(systemName: systemImage ?? "xmark.square").resizable().aspectRatio( contentMode: .fit).scaleEffect(CGSize(width: iconScale, height: iconScale)).foregroundColor(self.iconColor)
                }
            } }
).labelStyle(HorizontallyAlignedLabelStyle())
    }
}

struct ZZLabel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZZLabel(text: "Hello")
            ZZLabel(iconBackgroundColor: .blue, iconColor: .white, systemImage: "square", image: nil, text: "Hello Square", iconScale: 0.6)
        }.previewLayout(.sizeThatFits)
    }
}
