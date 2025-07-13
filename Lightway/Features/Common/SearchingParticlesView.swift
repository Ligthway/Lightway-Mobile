//
//  SearchingParticlesView.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import GlowGetter
import SwiftUI

struct SearchingParticlesView: View {
    @State private var animating = false
    let showSearching: Bool
    
    init(showSearching: Bool = true) {
        self.showSearching = showSearching
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                FallingMetalParticleView(height: 90)
                    .frame(height: 90)
                    .opacity(0.7)
                if (showSearching) {
                    Text("Searching...")
                        .foregroundStyle(.white)
                        .bold()
                        .font(.title3)
                        .glow(0.8)
                        .opacity(animating ? 1 : 0.3)
                        .mask(
                            Text("Searching...")
                                .foregroundStyle(.white)
                                .bold()
                                .font(.title3)
                        )
                        .padding(.top, 55)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

#Preview {
    SearchingParticlesView()
        .background(.black)
        .ignoresSafeArea()
}
