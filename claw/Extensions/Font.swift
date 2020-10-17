//
//  Font.swift
//  claw
//
//  Created by Zachary Gorak on 10/13/20.
//

import Foundation
import UIKit
import SwiftUI

extension UIFont {
    public var weight: UIFont.Weight {
        guard let weightNumber = traits[.weight] as? NSNumber else { return self.weight2 }
            let weightRawValue = CGFloat(weightNumber.doubleValue)
            let weight = UIFont.Weight(rawValue: weightRawValue)
            return weight
        }

        private var traits: [UIFontDescriptor.TraitKey: Any] {
            return fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
                ?? [:]
        }
    private var weight2: UIFont.Weight {
        let fontAttributeKey = UIFontDescriptor.AttributeName.init(rawValue: "NSCTFontUIUsageAttribute")
        if let fontWeight = self.fontDescriptor.fontAttributes[fontAttributeKey] as? String {
            switch fontWeight {
            case "CTFontBoldUsage":
                return UIFont.Weight.bold

            case "CTFontBlackUsage":
                return UIFont.Weight.black

            case "CTFontHeavyUsage":
                return UIFont.Weight.heavy

            case "CTFontUltraLightUsage":
                return UIFont.Weight.ultraLight

            case "CTFontThinUsage":
                return UIFont.Weight.thin

            case "CTFontLightUsage":
                return UIFont.Weight.light

            case "CTFontMediumUsage":
                return UIFont.Weight.medium

            case "CTFontDemiUsage":
                return UIFont.Weight.semibold

            case "CTFontRegularUsage":
                return UIFont.Weight.regular

            default:
                return UIFont.Weight.regular
            }
        }
        return .regular
    }
    
    public var fontWeight: Font.Weight {
        switch self.weight {
        case .regular:
            return .regular
        case .black:
            return .black
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .thin:
            return .thin
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        default:
            return .regular
        }
    }
}

extension Font.TextStyle {
    var uiStyle: UIFont.TextStyle {
        switch(self) {
        case .body: return .body
        case .callout: return .callout
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .footnote:
            return .footnote
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        @unknown default:
            return .body
        }
    }
}
extension Font {
    init(_ style: Font.TextStyle, sizeModifier: CGFloat = 0.0, weight: Font.Weight? = nil, design: Font.Design = .default) {
        let base = UIFont.preferredFont(forTextStyle: style.uiStyle)
        let weight = weight ?? base.fontWeight
        self = Font.system(size: base.pointSize + sizeModifier, weight: weight, design: design)
    }
}
