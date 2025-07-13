//
//  InformationSheetView.swift
//  Lightway
//
//  Created by Alexandru Simedrea on 13.07.2025.
//

import SwiftUI

struct InformationSheetView: View {
    @Environment(NavigationMode.self) var navigationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Information Found")
                .font(.title.bold())

            Button {
                withAnimation {
                    navigationMode.setIsNavigating(true)
                }
            } label: {
                HStack {
                    Image(systemName: "play")
                    Text("Start Navigation")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassEffect(.regular.tint(.green))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    InformationSheetView()
}
