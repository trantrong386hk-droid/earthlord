//
//  TerritoryTestView.swift
//  earthlord
//
//  圈地功能测试界面
//  显示实时状态和调试日志
//  注意：不需要 NavigationStack，因为已经在 TestMenuView 的导航链接中
//

import SwiftUI

// MARK: - 圈地测试视图

struct TerritoryTestView: View {

    // MARK: - 状态对象

    /// 定位管理器（单例）
    @StateObject private var locationManager = LocationManager.shared

    /// 日志管理器（单例）
    @StateObject private var logger = TerritoryLogger.shared

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // MARK: - 状态指示区
                statusSection

                // MARK: - 日志显示区
                logSection

                // MARK: - 操作按钮
                buttonSection
            }
            .padding()
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态指示区

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("状态监控")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 20) {
                // 追踪状态
                StatusItem(
                    icon: locationManager.isTracking ? "location.fill" : "location.slash",
                    title: "追踪",
                    value: locationManager.isTracking ? "进行中" : "未开始",
                    color: locationManager.isTracking ? ApocalypseTheme.success : ApocalypseTheme.textMuted
                )

                // 路径点数
                StatusItem(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    title: "路径点",
                    value: "\(locationManager.pathPointCount)",
                    color: ApocalypseTheme.primary
                )

                // 闭环状态
                StatusItem(
                    icon: locationManager.isPathClosed ? "checkmark.circle.fill" : "circle.dashed",
                    title: "闭环",
                    value: locationManager.isPathClosed ? "已闭合" : "未闭合",
                    color: locationManager.isPathClosed ? ApocalypseTheme.success : ApocalypseTheme.warning
                )
            }

            // 速度警告
            if let warning = locationManager.speedWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ApocalypseTheme.danger)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.danger.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 日志显示区

    private var logSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("调试日志")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(logger.logs.count) 条")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logger.logs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .onChange(of: logger.logs.count) {
                    // 自动滚动到最新日志
                    if let lastLog = logger.logs.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮

    private var buttonSection: some View {
        HStack(spacing: 12) {
            // 清空日志
            Button {
                logger.clear()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.textMuted)
                .cornerRadius(10)
            }

            // 导出日志
            ShareLink(item: logger.export()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - 状态项组件

private struct StatusItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 日志条目行

private struct LogEntryRow: View {
    let entry: LogEntry

    /// 时间格式化器
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 日志类型标签
            Text(entry.type.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(typeColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(typeColor.opacity(0.2))
                .cornerRadius(4)

            // 日志内容
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 根据日志类型返回颜色
    private var typeColor: Color {
        switch entry.type {
        case .info:
            return ApocalypseTheme.textSecondary
        case .success:
            return ApocalypseTheme.success
        case .warning:
            return ApocalypseTheme.warning
        case .error:
            return ApocalypseTheme.danger
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
    }
}
