//
//  MapTabView.swift
//  earthlord
//
//  地图页面
//  显示末世风格地图，用户位置追踪
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
                shouldRecenter: $shouldRecenter
            )
            .ignoresSafeArea()

            // 右下角控制按钮
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    // 控制按钮组
                    VStack(spacing: 12) {
                        // 定位按钮
                        locationButton

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
