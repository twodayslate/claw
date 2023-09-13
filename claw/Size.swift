//
//  Size.swift
//  redgifs
//
//  Created by Zachary Gorak on 6/16/23.
//

import SwiftUI

private struct SizeCalculator: ViewModifier {

    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear // we just want the reader to get triggered, so let's use an empty color
                        .onAppear {
                            size = proxy.size
                        }
                }
            )
    }

}

extension View {
    func saveSize(in size: Binding<CGSize>) -> some View {
        modifier(SizeCalculator(size: size))
    }
}
