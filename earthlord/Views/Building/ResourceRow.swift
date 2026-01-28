//
//  ResourceRow.swift
//  earthlord
//
//  资源需求行组件
//

import SwiftUI

/// 资源需求行
struct ResourceRow: View {

    let resourceName: String
    let requiredAmount: Int
    let availableAmount: Int?

    /// 是否足够
    private var isSufficient: Bool {
        guard let available = availableAmount else { return true }
        return available >= requiredAmount
    }

    /// 资源图标
    private var resourceIcon: String {
        switch resourceName {
        case "木材":
            return "tree.fill"
        case "石头":
            return "mountain.2.fill"
        case "金属板":
            return "rectangle.3.offgrid.fill"
        case "电子元件":
            return "cpu.fill"
        default:
            return "cube.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .font(.subheadline)
                .foregroundColor(isSufficient ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)
                .frame(width: 24)

            // 资源名称
            Text(resourceName)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量显示
            if let available = availableAmount {
                HStack(spacing: 4) {
                    Text("\(available)")
                        .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
                    Text("/")
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("\(requiredAmount)")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .font(.subheadline)
            } else {
                Text("x\(requiredAmount)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 状态指示
            if availableAmount != nil {
                Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack(spacing: 8) {
            ResourceRow(resourceName: "木材", requiredAmount: 50, availableAmount: 80)
            ResourceRow(resourceName: "石头", requiredAmount: 30, availableAmount: 20)
            ResourceRow(resourceName: "金属板", requiredAmount: 40, availableAmount: nil)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding()
    }
}
