//
//  ContentView.swift
//  SliderComparisonViewDemo
//
//  Created by Paresh  Karnawat on 28/10/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        
        SliderComparisonView(
            lhs: {
                Image("BWNature")
                    .resizable()
            },
            rhs: {
                Image("Nature")
                    .resizable()
            }
        )
        .indicatorImage(Image(systemName: "arrow.down.left.and.arrow.up.right"))
        .indicatorColor(.white)
        .indicatorImageColor(.black)
        .dividerColor(.white)
        .dividerWidth(2)
        .initialProgress(0.3)
    }
}

#Preview {
    ContentView()
}
