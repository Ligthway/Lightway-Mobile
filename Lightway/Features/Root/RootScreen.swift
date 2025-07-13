//
//  RootScreen.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import SwiftUI

@Observable
class NavigationMode {
    private(set) var isNavigating: Bool
    
    init(isNavigating: Bool) {
        self.isNavigating = isNavigating
    }
    
    convenience init() {
        self.init(isNavigating: false)
    }
    
    func setIsNavigating(_ isNavigating: Bool) {
        self.isNavigating = isNavigating
    }
}

struct RootScreen: View {
    enum Tabs: Hashable, CaseIterable {
        case home
        case collection
        case profile

        var title: String {
            switch self {
            case .home:
                return "Home"
            case .collection:
                return "Collection"
            case .profile:
                return "Profile"
            }
        }

        var iconName: String {
            switch self {
            case .home:
                return "house"
            case .collection:
                return "square.grid.2x2"
            case .profile:
                return "person"
            }
        }

        var view: AnyView {
            switch self {
            case .home:
                AnyView(HomeScreen())
            case .collection:
                AnyView(Text("Collection"))
            case .profile:
                AnyView(Text("Profile"))
            }
        }
    }
    
    @State private var navigationMode: NavigationMode = .init()

    var body: some View {
        if navigationMode.isNavigating {
            NavigationScreen()
                .environment(navigationMode)
        } else {
            TabView {
                ForEach(Tabs.allCases.filter { $0 != .profile }, id: \.self) {
                    tab in
                    Tab(tab.title, systemImage: tab.iconName) {
                        tab.view
                    }
                }
                Tab(Tabs.profile.title, systemImage: Tabs.profile.iconName, role: .search) {
                    Tabs.profile.view
                }
            }
            .environment(navigationMode)
        }
    }
}

#Preview {
    RootScreen()
}
