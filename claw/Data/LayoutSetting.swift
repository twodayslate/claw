//
//  LayoutSetting.swift
//  claw
//
//  Created by Zachary Gorak on 7/13/25.
//

enum LayoutSetting: Double, Equatable, Comparable {
    static func < (lhs: LayoutSetting, rhs: LayoutSetting) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    case compact = 0.0
    case comfortable = 1.0
    case Default = 2.0
}
