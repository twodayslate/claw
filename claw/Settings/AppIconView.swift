//
//  AppIconView.swift
//  claw
//
//  Created by Zachary Gorak on 10/13/22.
//

import Foundation
import SwiftUI

struct AppIcon: Codable {
    var alternateIconName: String?
    var name: String
    var assetName: String
    var subtitle: String?
}

struct AppIconView: View {
    var icon: AppIcon
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        HStack {
            let path = Bundle.main.resourcePath?.appending(icon.assetName) ?? icon.assetName
            if let image = UIImage(contentsOfFile: path) ?? UIImage(named: icon.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .mask(
                        Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    )
            }
            VStack(alignment: .leading) {
                Text("\(icon.name)").foregroundColor(Color(UIColor.label))
                if let subtitle = icon.subtitle {
                    Text("\(subtitle)").foregroundColor(.gray)
                        .font(Font(.subheadline, sizeModifier: CGFloat(settings.textSizeModifier)))
                }
            }
            
            if settings.alternateIconName == icon.alternateIconName {
                Spacer()
                Text("\(Image(systemName: "checkmark"))").bold().foregroundColor(.accentColor)
            }
        }
    }
}
