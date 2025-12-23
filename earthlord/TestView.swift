//
//  TestView.swift
//  earthlord
//
//  Created by lili on 2025/12/23.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.2)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    TestView()
}
