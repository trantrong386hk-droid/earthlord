//
//  ContentView.swift
//  earthlord
//
//  Created by lili on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("Developed by lilizhou")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
