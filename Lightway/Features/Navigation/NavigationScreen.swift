//
//  NavigationScreen.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import GlowGetter
import SmoothGradient
import SwiftUI

struct NavigationScreen: View {
    @Environment(NavigationMode.self) var navigationMode
    @Namespace private var namespace
    @State private var isShowingSheet: Bool = false
    @State private var isShowingTiltUpwards: Bool = false

    private var directionsText: some View {
        (Text(
            Image(
                systemName:
                    "arrow.turn.up.right"
            )
        )
            + Text(" In 10m, turn right"))
            .font(
                .system(
                    size: 24,
                    weight: .bold,
                    design: .default
                )
            )
    }
    
    private func directionsIndications(geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            directionsText
                .glow(0.6, .rect(cornerRadius: 40))
                .mask {
                    directionsText
                }
                .foregroundStyle(.white)
                .padding(.top, 88)
            
            FallingMetalParticlesWithRectangleView(height: 400)
                .frame(width: geo.size.width, height: 400)
                .clipped()
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    CameraView()
                        .frame(width: geo.size.width, height: geo.size.height)

                    SmoothLinearGradient(
                        from: .black.opacity(0.85),
                        to: .clear,
                        startPoint: .top,
                        endPoint: .bottom,
                        curve: .easeInOut
                    )
                    .frame(height: 380)
                    
                    if isShowingTiltUpwards {
                        TiltUpwardsView()
                    } else {
                        directionsIndications(geo: geo)
                    }
                }
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isShowingSheet.toggle()
                    } label: {
                        HStack {
                            Image(.greenApple)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            (Text("Going to ")
                                .foregroundStyle(.foreground.opacity(0.7))
                                + Text("Green Apples").bold())
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .matchedTransitionSource(id: "test", in: namespace)

                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        withAnimation {
                            isShowingTiltUpwards.toggle()
                        }
                    } label: {
                        Text("4 items")
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 6)
                }
            }
            .sheet(isPresented: $isShowingSheet) {
                VStack {
                    HStack {
                        Image(.greenApple)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading) {
                            Text("Green Apples")
                                .font(.title2)
                                .bold()
                            Text("Arriving in 3 minutes")
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Button {
                        navigationMode.setIsNavigating(false)
                    } label: {
                        Text("End Navigation")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(.red))
                    .offset(y: 18)
                }
                .padding(.bottom, 0)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .presentationDetents([.height(200)])
                .navigationTransition(.zoom(sourceID: "test", in: namespace))
                .safeAreaPadding(.bottom, 0)
            }
        }
    }
}

#Preview {
    NavigationScreen()
}
