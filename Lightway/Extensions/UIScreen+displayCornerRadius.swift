//
//  UIScreen+displayCornerRadius.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import SwiftUI

extension UIScreen {
    public var displayCornerRadius: CGFloat {
        guard
            let cornerRadius = self.value(forKey: "_displayCornerRadius")
                as? CGFloat
        else {
            return 0
        }
        return cornerRadius
    }
}
