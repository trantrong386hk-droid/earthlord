//
//  CategoryButton.swift
//  earthlord
//
//  建筑分类按钮组件
//

import SwiftUI

/// 建筑分类按钮
struct CategoryButton: View {

    let category: BuildingCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.subheadline)

                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        HStack(spacing: 12) {
            CategoryButton(category: .survival, isSelected: true) {}
            CategoryButton(category: .storage, isSelected: false) {}
            CategoryButton(category: .production, isSelected: false) {}
        }
        .padding()
    }
}
