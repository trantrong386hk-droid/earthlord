//
//  TerritoryToolbarView.swift
//  earthlord
//
//  领地悬浮工具栏
//  显示领地名称和操作按钮
//

import SwiftUI

/// 领地悬浮工具栏
struct TerritoryToolbarView: View {

    // MARK: - 属性

    let territoryName: String
    let buildingCount: Int
    let onBack: () -> Void
    let onRename: () -> Void
    let onBuild: () -> Void
    let onToggleInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ApocalypseTheme.cardBackground.opacity(0.9))
                    )
            }

            // 领地名称
            VStack(alignment: .leading, spacing: 2) {
                Text(territoryName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.caption2)
                    Text("\(buildingCount) 座建筑")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground.opacity(0.9))
            )
            .onTapGesture {
                onRename()
            }

            Spacer()

            // 建造按钮
            Button(action: onBuild) {
                Image(systemName: "hammer.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ApocalypseTheme.cardBackground.opacity(0.9))
                    )
            }

            // 信息按钮
            Button(action: onToggleInfo) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(ApocalypseTheme.cardBackground.opacity(0.9))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        Color.gray
            .ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                territoryName: "我的第一块领地",
                buildingCount: 3,
                onBack: {},
                onRename: {},
                onBuild: {},
                onToggleInfo: {}
            )

            Spacer()
        }
    }
}
