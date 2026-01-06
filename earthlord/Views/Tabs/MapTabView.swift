//
//  MapTabView.swift
//  earthlord
//
//  地图页面
//  显示末世风格地图，用户位置追踪，路径圈地
//

import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {

    // MARK: - 属性

    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser: Bool = false

    /// 是否需要重新居中
    @State private var shouldRecenter: Bool = false

    /// 是否显示圈地确认弹窗
    @State private var showClaimAlert: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 根据授权状态显示不同内容
            if locationManager.isDenied {
                // 定位被拒绝 - 显示提示卡片
                locationDeniedView
            } else {
                // 显示地图
                mapContent
            }
        }
        .onAppear {
            // 首次出现时请求定位权限
            if locationManager.isNotDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
        .id(languageManager.refreshID)
    }

    // MARK: - 地图内容

    private var mapContent: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                shouldRecenter: $shouldRecenter,
                trackingPath: locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed
            )
            .ignoresSafeArea()

            // 顶部信息卡片
            VStack(spacing: 12) {
                // 圈地信息卡片（追踪时显示）
                if locationManager.isTracking {
                    trackingInfoCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 速度警告卡片
                if locationManager.speedWarning != nil {
                    speedWarningCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)  // 避开状态栏
            .animation(.easeInOut(duration: 0.3), value: locationManager.isTracking)
            .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning != nil)

            // 右下角控制按钮
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    // 控制按钮组
                    VStack(spacing: 12) {
                        // 定位按钮
                        locationButton

                        // 圈地按钮
                        claimTerritoryButton

                        // 坐标信息卡片
                        if let location = userLocation {
                            coordinateCard(location: location)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)  // 避开底部 Tab 栏
                }
            }

            // 加载中状态
            if locationManager.isNotDetermined {
                loadingOverlay
            }
        }
    }

    // MARK: - 圈地信息卡片

    private var trackingInfoCard: some View {
        VStack(spacing: 12) {
            // 标题栏
            HStack {
                // 红点 + 标题
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)

                    Text("正在圈地".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                // 关闭按钮
                Button {
                    locationManager.stopPathTracking()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .clipShape(Circle())
                }
            }

            // 统计数据
            HStack(spacing: 0) {
                // 时长
                VStack(alignment: .leading, spacing: 4) {
                    Text("时长".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(locationManager.formattedDuration)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 距离
                VStack(alignment: .leading, spacing: 4) {
                    Text("距离".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(locationManager.formattedDistance)
                        .font(.title2.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 坐标点
                VStack(alignment: .leading, spacing: 4) {
                    Text("坐标点".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("\(locationManager.pathPointCount)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8)
    }

    // MARK: - 速度警告卡片

    private var speedWarningCard: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(ApocalypseTheme.warning)

            // 文字内容
            VStack(alignment: .leading, spacing: 2) {
                Text("速度警告".localized)
                    .font(.subheadline.bold())
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(locationManager.speedWarning ?? "")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 关闭按钮
            Button {
                locationManager.speedWarning = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(ApocalypseTheme.textMuted.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8)
    }

    // MARK: - 定位按钮

    private var locationButton: some View {
        Button {
            // 重新居中到用户位置
            shouldRecenter = true
        } label: {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.title2)
                .foregroundColor(hasLocatedUser ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.cardBackground.opacity(0.95))
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.3), radius: 5)
        }
    }

    // MARK: - 圈地按钮

    private var claimTerritoryButton: some View {
        Button {
            if locationManager.isTracking {
                // 停止追踪，显示确认弹窗
                locationManager.stopPathTracking()

                // 如果路径有效，显示确认弹窗
                if locationManager.pathPointCount >= 3 {
                    showClaimAlert = true
                }
            } else {
                // 开始追踪
                locationManager.startPathTracking()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.title3)

                Text(locationManager.isTracking ? "停止圈地".localized : "开始圈地".localized)
                    .font(.subheadline.bold())

                // 追踪中显示当前点数
                if locationManager.isTracking {
                    Text("\(locationManager.pathPointCount)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.3), radius: 5)
        }
        .alert("圈地完成".localized, isPresented: $showClaimAlert) {
            Button("确认".localized, role: .cancel) {
                // 清除路径，准备下一次圈地
                locationManager.clearPath()
            }
        } message: {
            if locationManager.isPathClosed {
                Text(verbatim: String(format: "恭喜！您已成功圈定一块领地，共记录 %lld 个点。".localized, locationManager.pathPointCount))
            } else {
                Text(verbatim: String(format: "路径未闭合，请确保起点和终点距离在 30 米以内，且至少记录 10 个点。共记录 %lld 个点。".localized, locationManager.pathPointCount))
            }
        }
    }

    // MARK: - 坐标信息卡片

    private func coordinateCard(location: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                Text("当前坐标".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 5)
    }

    // MARK: - 定位被拒绝视图

    private var locationDeniedView: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text("需要定位权限".localized)
                .font(.title2.bold())
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("《地球新主》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 前往设置按钮
            Button {
                locationManager.openSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("前往设置".localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - 加载中遮罩

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.2)

            Text("正在请求定位权限...".localized)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(32)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
    }
}

#Preview {
    MapTabView()
}
