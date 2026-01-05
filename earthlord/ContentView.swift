//
//  ContentView.swift
//  earthlord
//
//  Created by lili on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                Text("Developed by lilizhou")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                NavigationLink("进入测试页") {
                    TestMenuView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 30)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
