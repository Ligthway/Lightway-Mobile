//
//  HomeScreen.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import GlowGetter
import SmoothGradient
import SwiftUI

struct HomeScreen: View {
    private let screenCornerRadius = UIScreen.main.displayCornerRadius
    @State private var isShowingInformationSheet: Bool = false
    @State private var blurRadius: CGFloat = 0
    @State private var secondaryBlurRadius: CGFloat = 0
    @State private var overlayOpacity: CGFloat = 0
    @State private var showSearching: Bool = true

    private func showInformationSheet() {
        withAnimation {
            showSearching = false
        }
        withAnimation(.snappy(duration: 0.9).delay(0.3)) {
            isShowingInformationSheet = true
        }
        withAnimation(.smooth(duration: 0.4)) {
            blurRadius = 10
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.4
        ) {
            withAnimation(.smooth(duration: 1)) {
                blurRadius = 0
                secondaryBlurRadius = 20
                overlayOpacity = 0.75
            }
        }
    }

    private func hideInformationSheet() {
        withAnimation {
            isShowingInformationSheet = false
            secondaryBlurRadius = 0
            overlayOpacity = 0
            showSearching = true
        }
    }

    private func toggleInformationSheet() {
        if isShowingInformationSheet {
            hideInformationSheet()
        } else {
            showInformationSheet()
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                CameraView()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: secondaryBlurRadius)
                    .overlay {
                        Color(.systemBackground).opacity(overlayOpacity)
                            .frame(
                                width: geo.size.width,
                                height: geo.size.height
                            )
                    }

                if overlayOpacity == 0 {
                    SmoothLinearGradient(
                        from: .black.opacity(0.85),
                        to: .clear,
                        startPoint: .top,
                        endPoint: .bottom,
                        curve: .easeInOut
                    )
                    .frame(height: 380)
                }

                SearchingParticlesView(showSearching: showSearching)
                    .opacity(overlayOpacity > 0 ? 0.3 : 1)
                    .onTapGesture {
                        toggleInformationSheet()
                    }

                Circle()
                    .fill(Color.white)
                    .glow(0.8, .circle)
                    .offset(y: -geo.size.width / 2 - 80)
                    .blur(radius: 50)
                    .opacity(blurRadius > 0 ? 1 : 0)

                VStack {
                    Spacer()

                    Button {
                    } label: {
                        VStack {
                            InformationSheetView()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .frame(
                        width: max(0, geo.size.width - 32),
                        height: 300
                    )
                    .glassEffect(
                        in: .rect(
                            cornerRadius: screenCornerRadius - 8
                        )
                    )
                    .offset(
                        y: isShowingInformationSheet
                            ? -UITabBarController().height - 20 : -4000
                    )
                    .scaleEffect(isShowingInformationSheet ? 1 : 0.2)
                }
            }
            .blur(radius: blurRadius)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    HomeScreen()
}
