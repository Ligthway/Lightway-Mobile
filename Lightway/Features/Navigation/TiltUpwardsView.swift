//
//  WaveDotsView.swift
//  particle slider
//
//  Created by Alexandru Simedrea on 12.07.2025.
//

import SwiftUI

struct TiltUpwardsView: View {
    var body: some View {
        ZStack {
            DotsWaveMetalView()
                .frame(height: 150)

            HStack {
                Image(systemName: "arrow.up")
                    .symbolEffect(
                        .wiggle,
                        options: .repeat(.continuous).speed(0.5)
                    )
                Text("Tilt your phone upwards")
            }
            .foregroundStyle(.white)
            .font(.title2)
            .bold()
        }
    }
}
