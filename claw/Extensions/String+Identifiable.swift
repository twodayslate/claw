//
//  String+Identifiable.swift
//  claw
//
//  Created by Zachary Gorak on 9/10/23.
//

import Foundation

extension String: Identifiable {
    public var id: String {
        return self
    }
}
