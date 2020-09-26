//
//  UIColor.swift
//  claw
//
//  Created by Zachary Gorak on 9/13/20.
//

import Foundation
import UIKit
import SwiftUI

//https://stackoverflow.com/a/63003757/193772
extension UIColor {
    func mix(with color: UIColor, amount: CGFloat) -> Self {
        var red1: CGFloat = 0
        var green1: CGFloat = 0
        var blue1: CGFloat = 0
        var alpha1: CGFloat = 0

        var red2: CGFloat = 0
        var green2: CGFloat = 0
        var blue2: CGFloat = 0
        var alpha2: CGFloat = 0

        getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        color.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)

        return Self(
            red: red1 * CGFloat(1.0 - amount) + red2 * amount,
            green: green1 * CGFloat(1.0 - amount) + green2 * amount,
            blue: blue1 * CGFloat(1.0 - amount) + blue2 * amount,
            alpha: alpha1
        )
    }

    func lighter(by amount: CGFloat = 0.2) -> Self { mix(with: .white, amount: amount) }
    func darker(by amount: CGFloat = 0.2) -> Self { mix(with: .black, amount: amount) }
}

extension UIColor {
    var data: Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
}

extension UIColor {
    
    static var lobstersRed = UIColor.init(red: 158.0/255.0, green: 38.0/255.0, blue: 27.0/255.0, alpha: 1.0)
    
    var name: String? {
        if #available(iOS 13.0, *) {
            switch self {
                case .systemIndigo:
                    return "System Indigo"
            default:
                break
            }
        }
        switch self {
        case .lobstersRed:
            return "Lobsters Red"
        case .systemPurple:
            return "System Purple"
        case .systemOrange:
            return "System Orange"
        case .systemTeal:
            return "System Teal"
        case .systemPink:
            return "System Pink"
        case .systemBlue:
            return "System Blue"
        case .systemRed:
            return "System Red"
        case .systemGray:
            return "System Gray"
        case .systemGreen:
            return "System Green"
        case .systemYellow:
            return "System Yellow"
        case .white:
            return "White"
        case .black:
            return "Black"
        default:
            return nil
        }
    }
}
