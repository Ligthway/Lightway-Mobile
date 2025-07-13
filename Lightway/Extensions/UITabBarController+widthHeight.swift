//
//  UITabBarController+widthHeight.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import SwiftUI

extension UITabBarController {
    var height: CGFloat {
        return self.tabBar.frame.size.height
    }

    var width: CGFloat {
        return self.tabBar.frame.size.width
    }
}
