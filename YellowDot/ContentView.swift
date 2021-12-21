//
//  ContentView.swift
//  YellowDot
//
//  Created by Alin Panaitiu on 21.12.2021.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        Circle()
            .frame(width: 100, height: 100, alignment: .center)
            .background(.black)
            .padding()
    }
}

// MARK: - ContentView_Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
