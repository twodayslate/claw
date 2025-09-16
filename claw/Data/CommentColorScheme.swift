//
//  CommentColorScheme.swift
//  claw
//
//  Created by Zachary Gorak on 7/13/25.
//

import UIKit
import SwiftUI

enum CommentColorScheme: Codable, Equatable{
        case `default`
        case red
        case blue
        case purple
        case custom(UIColor, UIColor, UIColor, UIColor, UIColor, UIColor, UIColor)
        case label
        case green
        case gray
        case yellow
        case teal
        case orange
        case indigo
        case mint

        var colors: [Color] {
            switch self {
            case .default:
                return [Color.blue, Color.red, Color.green, Color.orange, Color.pink, Color.yellow, Color.purple].map { $0.opacity(0.5) }
            case .red:
                return [Color.red.opacity(1.0), Color.red.opacity(0.9), Color.red.opacity(0.8), Color.red.opacity(0.7), Color.red.opacity(0.6), Color.red.opacity(0.5), Color.red.opacity(0.4)]
            case .blue:
                return [Color.blue.opacity(1.0), Color.blue.opacity(0.9), Color.blue.opacity(0.8), Color.blue.opacity(0.7), Color.blue.opacity(0.6), Color.blue.opacity(0.5), Color.blue.opacity(0.4)]
            case .green:
                return [Color.green.opacity(1.0), Color.green.opacity(0.9), Color.green.opacity(0.8), Color.green.opacity(0.7), Color.green.opacity(0.6), Color.green.opacity(0.5), Color.green.opacity(0.4)]
            case .purple:
                return [Color.purple.opacity(1.0), Color.purple.opacity(0.9), Color.purple.opacity(0.8), Color.purple.opacity(0.7), Color.purple.opacity(0.6), Color.purple.opacity(0.5), Color.purple.opacity(0.4)]
            case let .custom(one, two, three, four, five, six, seven):
                return [one, two, three, four, five, six, seven].map { Color($0) }
            case .label:
                return [Color(UIColor.label).opacity(1.0), Color(UIColor.label).opacity(0.9), Color(UIColor.label).opacity(0.8), Color(UIColor.label).opacity(0.7), Color(UIColor.label).opacity(0.6), Color(UIColor.label).opacity(0.4), Color(UIColor.label).opacity(0.4)]
            case .gray:
                return [Color.gray.opacity(1.0), Color.gray.opacity(0.9), Color.gray.opacity(0.8), Color.gray.opacity(0.7), Color.gray.opacity(0.6), Color.gray.opacity(0.5), Color.gray.opacity(0.4)]
            case .yellow:
                return [Color.yellow.opacity(1.0), Color.yellow.opacity(0.9), Color.yellow.opacity(0.8), Color.yellow.opacity(0.7), Color.yellow.opacity(0.6), Color.yellow.opacity(0.5), Color.yellow.opacity(0.4)]
            case .teal:
                return [Color.teal.opacity(1.0), Color.teal.opacity(0.9), Color.teal.opacity(0.8), Color.teal.opacity(0.7), Color.teal.opacity(0.6), Color.teal.opacity(0.5), Color.teal.opacity(0.4)]
            case .orange:
                return [Color.orange.opacity(1.0), Color.orange.opacity(0.9), Color.orange.opacity(0.8), Color.orange.opacity(0.7), Color.orange.opacity(0.6), Color.orange.opacity(0.5), Color.orange.opacity(0.4)]
            case .indigo:
                return [Color.indigo.opacity(1.0), Color.indigo.opacity(0.9), Color.indigo.opacity(0.8), Color.indigo.opacity(0.7), Color.indigo.opacity(0.6), Color.indigo.opacity(0.5), Color.indigo.opacity(0.4)]
            case .mint:
                return [Color.mint.opacity(1.0), Color.mint.opacity(0.9), Color.mint.opacity(0.8), Color.mint.opacity(0.7), Color.mint.opacity(0.6), Color.mint.opacity(0.5), Color.mint.opacity(0.4)]
            }
        }

        var name: String {
            switch self {
            case .default: return "Default"
            case .purple: return "Purple"
            case .blue: return "Blue"
            case .red: return "Red"
            case .label: return "Primary"
            case .green: return "Green"
            case .gray: return "Gray"
            case .yellow: return "Yellow"
            case .custom(_, _, _, _, _, _, _): return "Custom"
            case .teal: return "Teal"
            case .orange: return "Orange"
            case .indigo: return "Indigo"
            case .mint: return "Mint"
            }
        }

        var numbered: Int {
            switch self {
            case .default: return 0
            case .red: return 1
            case .custom(_, _, _, _, _, _, _): return 2
            case .blue: return 3
            case .purple: return 4
            case .label: return 5
            case .green: return 6
            case .gray: return 7
            case .yellow: return 8
            case .teal: return 9
            case .orange: return 10
            case .indigo: return 11
            case .mint: return 12
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case data
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(numbered, forKey: .type)
            switch self {
            case let .custom(one, two, three, four, five, six, seven):
                let values = [one, two, three, four, five, six, seven]
                let dataMap = values.compactMap { $0.data }
                let data = try JSONEncoder().encode(dataMap)
                try container.encode(data, forKey: .data)
            default:
                break
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(Int.self, forKey: .type)

            switch type {
            case CommentColorScheme.default.numbered:
                self = .default
            case CommentColorScheme.red.numbered:
                self = .red
            case CommentColorScheme.blue.numbered:
                self = .blue
            case CommentColorScheme.purple.numbered:
                self = .purple
            case CommentColorScheme.label.numbered:
                self = .label
            case CommentColorScheme.green.numbered:
                self = .green
            case CommentColorScheme.gray.numbered:
                self = .gray
            case CommentColorScheme.yellow.numbered:
                self = .yellow
            case CommentColorScheme.teal.numbered:
                self = .teal
            case CommentColorScheme.orange.numbered:
                self = .orange
            case CommentColorScheme.indigo.numbered:
                self = .indigo
            case CommentColorScheme.mint.numbered:
                self = .mint
            default:
                let data = try container.decode(Data.self, forKey: .data)
                let unwrapped = try JSONDecoder().decode([Data].self, from: data)
                let values: [UIColor] = unwrapped.compactMap { colorData in
                    guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) else {
                        return nil
                    }
                    return color
                }
                if values.count < 7 {
                    throw URLError(.cannotDecodeRawData)
                }
                self = .custom(values[0], values[1], values[2], values[3], values[4], values[5], values[6])
            }
        }
    }
