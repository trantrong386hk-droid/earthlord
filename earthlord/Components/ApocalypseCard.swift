import SwiftUI

/// 末日风格卡片组件
struct ApocalypseCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16
    var showBorder: Bool = false

    init(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        showBorder: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showBorder = showBorder
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        showBorder ? ApocalypseTheme.primary.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

// MARK: - 预设卡片样式

/// 信息卡片（带图标和标题）
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color

    init(
        icon: String,
        title: String,
        value: String,
        iconColor: Color = ApocalypseTheme.primary
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
    }

    var body: some View {
        ApocalypseCard {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()
            }
        }
    }
}

/// 统计卡片（带数字和单位）
struct StatCard: View {
    let icon: String
    let title: String
    let number: String
    let unit: String
    let color: Color

    init(
        icon: String,
        title: String,
        number: String,
        unit: String = "",
        color: Color = ApocalypseTheme.primary
    ) {
        self.icon = icon
        self.title = title
        self.number = number
        self.unit = unit
        self.color = color
    }

    var body: some View {
        ApocalypseCard(showBorder: true) {
            VStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(color)

                // 数值
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(number)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 标题
                Text(title)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// 操作卡片（可点击）
struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ApocalypseCard {
                HStack(spacing: 16) {
                    // 左侧图标
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 50, height: 50)
                        .background(ApocalypseTheme.primary.opacity(0.15))
                        .cornerRadius(10)

                    // 中间文字
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    // 右侧箭头
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("基础卡片") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack(spacing: 20) {
            ApocalypseCard {
                Text("这是一个基础卡片")
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ApocalypseCard(showBorder: true) {
                Text("带边框的卡片")
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding()
    }
}

#Preview("信息卡片") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack(spacing: 16) {
            InfoCard(
                icon: "flag.fill",
                title: "领地面积",
                value: "16,306 m²"
            )

            InfoCard(
                icon: "building.2.fill",
                title: "建筑数量",
                value: "12 座",
                iconColor: ApocalypseTheme.success
            )

            InfoCard(
                icon: "bolt.fill",
                title: "能源产出",
                value: "2,400 kW",
                iconColor: ApocalypseTheme.warning
            )
        }
        .padding()
    }
}

#Preview("统计卡片") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        HStack(spacing: 12) {
            StatCard(
                icon: "mappin.circle.fill",
                title: "已探索",
                number: "24",
                unit: "个",
                color: ApocalypseTheme.primary
            )

            StatCard(
                icon: "star.fill",
                title: "成就",
                number: "15",
                color: ApocalypseTheme.warning
            )
        }
        .padding()
    }
}

#Preview("操作卡片") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack(spacing: 16) {
            ActionCard(
                icon: "map.fill",
                title: "开始圈地",
                subtitle: "用双脚丈量你的领地"
            ) {
                print("开始圈地")
            }

            ActionCard(
                icon: "magnifyingglass",
                title: "探索废墟",
                subtitle: "搜刮物资，获取资源"
            ) {
                print("探索废墟")
            }

            ActionCard(
                icon: "hammer.fill",
                title: "建造建筑",
                subtitle: "发展你的领地"
            ) {
                print("建造建筑")
            }
        }
        .padding()
    }
}
