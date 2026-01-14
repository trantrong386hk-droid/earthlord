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
import UIKit
import Combine

struct MapTabView: View {

    // MARK: - 属性

    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared

    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 是否已完成首次定位
    @State private var hasLocatedUser: Bool = false

    /// 是否需要重新居中
    @State private var shouldRecenter: Bool = false

    /// 是否显示圈地确认弹窗
    @State private var showClaimAlert: Bool = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner: Bool = false

    /// 是否正在上传
    @State private var isUploading: Bool = false

    /// 上传结果消息
    @State private var uploadMessage: String?

    /// 是否显示上传结果
    @State private var showUploadResult: Bool = false

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning: Bool = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态

    /// 是否显示探索结果
    @State private var showExplorationResult: Bool = false

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

            // 加载领地
            Task {
                await loadTerritories()
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
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: authManager.userId?.uuidString,
                pois: explorationManager.nearbyPOIs,
                scavengedPOIIds: explorationManager.scavengedPOIIds
            )
            .ignoresSafeArea()

            // 顶部信息卡片
            VStack(spacing: 12) {
                // Day 19: 碰撞警告横幅（放在最上面）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBannerCompact(message: warning, level: collisionWarningLevel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索速度警告卡片（探索时超速显示）
                if explorationManager.state == .exploring, explorationManager.isOverSpeed {
                    explorationSpeedWarningCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 探索信息卡片（探索时显示）
                if explorationManager.state == .exploring {
                    explorationInfoCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 圈地信息卡片（追踪时显示）
                if locationManager.isTracking && explorationManager.state != .exploring {
                    trackingInfoCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 圈地速度警告卡片
                if locationManager.speedWarning != nil && explorationManager.state != .exploring {
                    speedWarningCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)  // 避开状态栏
            .animation(.easeInOut(duration: 0.3), value: locationManager.isTracking)
            .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning != nil)
            .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
            .animation(.easeInOut(duration: 0.3), value: explorationManager.state)
            .animation(.easeInOut(duration: 0.3), value: explorationManager.isOverSpeed)

            // 底部控制按钮
            VStack {
                Spacer()

                // 坐标信息卡片（底部按钮上方，右对齐）
                HStack {
                    Spacer()
                    if let location = userLocation {
                        coordinateCard(location: location)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // 底部按钮行：圈地 | 定位 | 探索
                HStack(spacing: 12) {
                    // 左侧：圈地按钮
                    claimTerritoryButton

                    // 中间：定位按钮
                    locationButton

                    // 右侧：探索按钮
                    exploreButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)  // 避开底部 Tab 栏
            }

            // 加载中状态
            if locationManager.isNotDetermined {
                loadingOverlay
            }

            // POI 接近提示弹窗
            if explorationManager.showPOIPopup, let poi = explorationManager.currentPOI {
                poiProximityPopup(poi: poi)
                    .transition(.scale.combined(with: .opacity))
            }

            // 验证结果横幅（在最上层）
            if showValidationBanner || locationManager.territoryValidationPassed {
                VStack {
                    validationResultBanner
                        .transition(.move(edge: .top).combined(with: .opacity))

                    // 验证通过时显示「确认登记」按钮
                    if locationManager.territoryValidationPassed && !isUploading {
                        confirmRegistrationButton
                            .transition(.scale.combined(with: .opacity))
                            .padding(.top, 8)
                    }

                    // 上传中显示进度
                    if isUploading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("正在登记领地...".localized)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                        .padding(.top, 8)
                    }

                    Spacer()
                }
                .animation(.easeInOut(duration: 0.3), value: showValidationBanner)
                .animation(.easeInOut(duration: 0.3), value: locationManager.territoryValidationPassed)
                .animation(.easeInOut(duration: 0.3), value: isUploading)
            }

            // 上传结果提示
            if showUploadResult, let message = uploadMessage {
                VStack {
                    uploadResultBanner(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.3), value: showUploadResult)
            }

        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 验证通过时不自动隐藏横幅，让用户可以点击登记
                    if !locationManager.territoryValidationPassed {
                        // 验证失败时 3 秒后自动隐藏
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showValidationBanner = false
                            }
                        }
                    }
                }
            }
        }
        // 探索结果弹窗
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationManager.currentResult {
                ExplorationResultView(
                    result: result,
                    stats: explorationManager.stats ?? MockExplorationResultData.stats
                )
                .onDisappear {
                    // 关闭结果页后重置状态
                    explorationManager.reset()
                }
            }
        }
        // POI 搜刮结果弹窗
        .sheet(isPresented: $explorationManager.showScavengeResult) {
            if let poi = explorationManager.currentPOI {
                ScavengeResultView(
                    poi: poi,
                    loot: explorationManager.scavengeLoot
                )
                .onDisappear {
                    explorationManager.dismissScavengeResult()
                }
            }
        }
        // 监听探索完成状态
        .onChange(of: explorationManager.state) { _, newState in
            if newState == .completed {
                showExplorationResult = true
            }
        }
        // Day 19: 路径更新时执行碰撞检测（比定时器更安全）
        .onChange(of: locationManager.pathUpdateVersion) { _, _ in
            if locationManager.isTracking {
                performCollisionCheck()
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

                // 实时状态指示器
                HStack(spacing: 8) {
                    // 闭环状态
                    HStack(spacing: 4) {
                        Image(systemName: locationManager.isPathClosed ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.caption)
                            .foregroundColor(locationManager.isPathClosed ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                        Text("闭环".localized)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 自交状态
                    if locationManager.hasSelfIntersection {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                            Text("自交".localized)
                                .font(.caption2)
                                .foregroundColor(ApocalypseTheme.danger)
                        }
                    }
                }

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

            // 统计数据（第一行）
            HStack(spacing: 0) {
                // 时长
                VStack(alignment: .leading, spacing: 4) {
                    Text("时长".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(locationManager.formattedDuration)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 行走距离
                VStack(alignment: .leading, spacing: 4) {
                    Text("行走".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(locationManager.formattedDistance)
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 实时速度
                VStack(alignment: .leading, spacing: 4) {
                    Text("速度".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(formattedSpeed)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(speedColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 坐标点
                VStack(alignment: .leading, spacing: 4) {
                    Text("点数".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("\(locationManager.pathPointCount)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 距离起点（第二行）
            HStack {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundColor(distanceToStartColor)

                Text("距起点".localized)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(formattedDistanceToStart)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(distanceToStartColor)

                Spacer()

                // 闭环提示
                if locationManager.pathPointCount >= 10 {
                    if locationManager.isPathClosed {
                        Text("已闭环".localized)
                            .font(.caption.bold())
                            .foregroundColor(ApocalypseTheme.success)
                    } else if locationManager.distanceToStart <= 50 {
                        Text("即将闭环".localized)
                            .font(.caption.bold())
                            .foregroundColor(ApocalypseTheme.warning)
                    }
                } else {
                    Text("还需 \(10 - locationManager.pathPointCount) 个点".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8)
    }

    /// 距离起点的格式化字符串
    private var formattedDistanceToStart: String {
        let distance = locationManager.distanceToStart
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// 距离起点的颜色（根据闭环状态变化）
    private var distanceToStartColor: Color {
        if locationManager.isPathClosed {
            return ApocalypseTheme.success
        } else if locationManager.distanceToStart <= 30 && locationManager.pathPointCount >= 10 {
            return ApocalypseTheme.success
        } else if locationManager.distanceToStart <= 50 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.textPrimary
        }
    }

    /// 格式化速度
    private var formattedSpeed: String {
        return String(format: "%.1f", locationManager.currentSpeed)
    }

    /// 速度颜色（根据速度变化）
    private var speedColor: Color {
        let speed = locationManager.currentSpeed
        if speed > 25 {
            return ApocalypseTheme.danger  // 严重超速
        } else if speed > 15 {
            return ApocalypseTheme.warning  // 轻微超速
        } else {
            return ApocalypseTheme.success  // 正常速度
        }
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

    // MARK: - 探索信息卡片

    /// 探索信息卡片（探索时显示距离、时长、速度）
    private var explorationInfoCard: some View {
        VStack(spacing: 12) {
            // 标题栏
            HStack {
                // 绿点 + 标题
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)

                    Text("正在探索".localized)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Spacer()

                // 预估等级
                HStack(spacing: 4) {
                    Image(systemName: explorationTierIcon)
                        .font(.caption)
                        .foregroundColor(explorationTierColor)
                    Text(explorationManager.estimatedTier.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(explorationTierColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(explorationTierColor.opacity(0.2))
                .cornerRadius(8)
            }

            // 统计数据
            HStack(spacing: 0) {
                // 时长
                VStack(alignment: .leading, spacing: 4) {
                    Text("时长".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(explorationManager.formattedDuration)
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 距离
                VStack(alignment: .leading, spacing: 4) {
                    Text("距离".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(explorationManager.formattedDistance)
                        .font(.title3.bold())
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 速度
                VStack(alignment: .leading, spacing: 4) {
                    Text("速度".localized)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(String(format: "%.1f", explorationManager.currentSpeed))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(explorationSpeedColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 奖励等级提示
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text(explorationTierHint)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8)
    }

    /// 探索等级图标
    private var explorationTierIcon: String {
        switch explorationManager.estimatedTier {
        case .none: return "xmark.circle"
        case .bronze: return "medal"
        case .silver: return "medal.fill"
        case .gold: return "star.fill"
        case .diamond: return "sparkles"
        }
    }

    /// 探索等级颜色
    private var explorationTierColor: Color {
        switch explorationManager.estimatedTier {
        case .none: return ApocalypseTheme.textMuted
        case .bronze: return Color.brown
        case .silver: return Color.gray
        case .gold: return Color.yellow
        case .diamond: return Color.cyan
        }
    }

    /// 探索等级提示
    private var explorationTierHint: String {
        switch explorationManager.estimatedTier {
        case .none: return "再走 \(Int(200 - explorationManager.currentDistance)) 米可获得铜级奖励"
        case .bronze: return "再走 \(Int(500 - explorationManager.currentDistance)) 米可升级为银级"
        case .silver: return "再走 \(Int(1000 - explorationManager.currentDistance)) 米可升级为金级"
        case .gold: return "再走 \(Int(2000 - explorationManager.currentDistance)) 米可升级为钻石级"
        case .diamond: return "已达到最高等级，继续探索！"
        }
    }

    /// 探索速度颜色
    private var explorationSpeedColor: Color {
        let speed = explorationManager.currentSpeed
        if speed > 30 {
            return ApocalypseTheme.danger
        } else if speed > 20 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    // MARK: - 探索速度警告卡片

    /// 探索速度警告卡片
    private var explorationSpeedWarningCard: some View {
        HStack(spacing: 12) {
            // 警告图标（带倒计时）
            ZStack {
                Circle()
                    .stroke(ApocalypseTheme.danger, lineWidth: 3)
                    .frame(width: 44, height: 44)

                Text("\(explorationManager.speedViolationCountdown)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 文字内容
            VStack(alignment: .leading, spacing: 2) {
                Text("速度过快！".localized)
                    .font(.subheadline.bold())
                    .foregroundColor(ApocalypseTheme.danger)

                Text(explorationManager.speedWarning ?? "请在倒计时结束前减速至 30 km/h 以下")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(ApocalypseTheme.danger.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.danger, lineWidth: 2)
        )
        .cornerRadius(16)
    }

    // MARK: - 验证结果横幅

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 50)
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

    // MARK: - 探索按钮

    private var exploreButton: some View {
        Button {
            handleExploreButtonTap()
        } label: {
            HStack(spacing: 8) {
                switch explorationManager.state {
                case .idle:
                    Image(systemName: "figure.walk")
                        .font(.title3)
                    Text("探索".localized)
                        .font(.subheadline.bold())

                case .exploring:
                    Image(systemName: "stop.fill")
                        .font(.title3)
                    Text("结束".localized)
                        .font(.subheadline.bold())
                    // 显示当前距离
                    Text(explorationManager.formattedDistance)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)

                case .finishing:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Text("生成奖励...".localized)
                        .font(.subheadline.bold())

                case .completed:
                    Image(systemName: "gift.fill")
                        .font(.title3)
                    Text("查看奖励".localized)
                        .font(.subheadline.bold())

                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                    Text("探索失败".localized)
                        .font(.subheadline.bold())
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(exploreButtonBackground)
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.3), radius: 5)
        }
        .disabled(explorationManager.state == .finishing)
    }

    /// 探索按钮背景色
    private var exploreButtonBackground: Color {
        switch explorationManager.state {
        case .idle:
            return ApocalypseTheme.primary
        case .exploring:
            return ApocalypseTheme.warning
        case .finishing:
            return ApocalypseTheme.textMuted
        case .completed:
            return ApocalypseTheme.success
        case .failed:
            return ApocalypseTheme.danger
        }
    }

    /// 处理探索按钮点击
    private func handleExploreButtonTap() {
        switch explorationManager.state {
        case .idle, .failed:
            // 开始探索（失败后也可以重新开始）
            explorationManager.startExploration()

        case .exploring:
            // 结束探索
            Task {
                await explorationManager.stopExploration()
            }

        case .finishing:
            // 生成中，不处理
            break

        case .completed:
            // 显示结果
            showExplorationResult = true
        }
    }

    // MARK: - 圈地按钮

    private var claimTerritoryButton: some View {
        Button {
            if locationManager.isTracking {
                // Day 19: 停止追踪时完全停止碰撞监控
                stopCollisionMonitoring()
                locationManager.stopPathTracking()

                // 如果路径有效，显示确认弹窗
                if locationManager.pathPointCount >= 3 {
                    showClaimAlert = true
                }
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
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
        .alert(locationManager.territoryValidationPassed ? "圈地成功".localized : "圈地失败".localized,
               isPresented: $showClaimAlert) {
            Button("确认".localized, role: .cancel) {
                // 清除路径，准备下一次圈地
                locationManager.clearPath()
                // 隐藏验证横幅
                showValidationBanner = false
            }
        } message: {
            if locationManager.territoryValidationPassed {
                // 验证通过：显示成功信息和面积
                Text(verbatim: String(format: "恭喜！您已成功圈定一块领地，面积 %.0f m²，共记录 %lld 个点。".localized,
                                      locationManager.calculatedArea,
                                      locationManager.pathPointCount))
            } else if locationManager.isPathClosed {
                // 闭环但验证失败：显示具体错误原因
                Text(verbatim: locationManager.territoryValidationError ?? "验证失败".localized)
            } else {
                // 未闭环
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

    // MARK: - 确认登记按钮

    private var confirmRegistrationButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                Text("确认登记领地".localized)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.success)
            .cornerRadius(25)
            .shadow(color: ApocalypseTheme.success.opacity(0.4), radius: 8)
        }
    }

    // MARK: - 上传结果横幅

    private func uploadResultBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(message.contains("成功") ? ApocalypseTheme.success : ApocalypseTheme.danger)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }

    // MARK: - 上传领地方法

    private func uploadCurrentTerritory() async {
        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showUploadError("领地验证未通过，无法上传".localized)
            return
        }

        // 检查是否正在上传
        guard !isUploading else { return }

        isUploading = true
        TerritoryLogger.shared.log("开始上传领地...", type: .info)

        do {
            // 上传领地
            let territory = try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startedAt: nil,  // 可以从 locationManager 获取开始时间
                completedAt: Date()
            )

            // 上传成功
            isUploading = false
            TerritoryLogger.shared.log("领地上传成功！ID: \(territory.id), 面积: \(Int(locationManager.calculatedArea))m²", type: .success)

            // 显示成功提示
            showUploadSuccess("领地登记成功！面积: \(Int(locationManager.calculatedArea))m²")

            // Day 19: 停止碰撞监控
            stopCollisionMonitoring()

            // 重置所有状态
            locationManager.resetAllState()

            // 隐藏验证横幅
            withAnimation {
                showValidationBanner = false
            }

            // 刷新领地列表以显示新上传的领地
            await loadTerritories()

        } catch {
            // 上传失败
            isUploading = false
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            showUploadError("上传失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 显示上传结果

    private func showUploadSuccess(_ message: String) {
        uploadMessage = message
        withAnimation {
            showUploadResult = true
        }
        // 3 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadResult = false
                uploadMessage = nil
            }
        }
    }

    private func showUploadError(_ message: String) {
        uploadMessage = message
        withAnimation {
            showUploadResult = true
        }
        // 5 秒后自动隐藏（错误信息显示更久）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                showUploadResult = false
                uploadMessage = nil
            }
        }
    }

    // MARK: - 加载领地

    /// 从服务器加载所有领地
    private func loadTerritories() async {
        do {
            try await territoryManager.loadAllTerritories()
            territories = territoryManager.territories
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// 当前用户 ID
    private var currentUserId: String? {
        authManager.userId?.uuidString
    }

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            // 如果没有位置或用户ID，直接开始圈地（兜底）
            locationManager.startPathTracking()
            startCollisionMonitoring()
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            HapticManager.shared.playFeedback(for: .violation)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        HapticManager.shared.prepare()  // 预热震动生成器
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控（使用 onChange 代替定时器，更安全）
    private func startCollisionMonitoring() {
        TerritoryLogger.shared.log("碰撞检测已启用", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        TerritoryLogger.shared.log("碰撞检测已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            HapticManager.shared.playFeedback(for: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            HapticManager.shared.playFeedback(for: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            HapticManager.shared.playFeedback(for: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            HapticManager.shared.playFeedback(for: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    // MARK: - POI 搜刮弹窗

    /// POI 接近提示弹窗
    private func poiProximityPopup(poi: POI) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // 图标和标题
                HStack(spacing: 12) {
                    // POI 类型图标
                    Image(systemName: poi.type.iconName)
                        .font(.title)
                        .foregroundColor(Color(poi.type.markerColor))
                        .frame(width: 50, height: 50)
                        .background(Color(poi.type.markerColor).opacity(0.2))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("发现废墟")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(poi.name)
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text(poi.type.displayName)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    Spacer()
                }

                // 危险等级提示
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(dangerLevelColor(poi.dangerLevel))
                    Text("危险等级: \(poi.dangerLevel)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                }

                // 按钮行
                HStack(spacing: 12) {
                    // 稍后再说按钮
                    Button {
                        withAnimation {
                            explorationManager.dismissPOIPopup()
                        }
                    } label: {
                        Text("稍后再说")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ApocalypseTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }

                    // 立即搜刮按钮
                    Button {
                        Task {
                            await explorationManager.scavengePOI(poi)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("立即搜刮")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(20)
            .background(ApocalypseTheme.cardBackground.opacity(0.98))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 120)  // 避开底部 Tab 栏
        }
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: explorationManager.showPOIPopup)
    }

    /// 危险等级颜色
    private func dangerLevelColor(_ level: Int) -> Color {
        switch level {
        case 1...2: return ApocalypseTheme.success
        case 3: return ApocalypseTheme.warning
        case 4...5: return ApocalypseTheme.danger
        default: return ApocalypseTheme.textMuted
        }
    }

    /// Day 19: 碰撞警告横幅（紧凑版，用于 VStack 内）
    private func collisionWarningBannerCompact(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack {
            Image(systemName: iconName)
                .font(.system(size: 16))

            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor.opacity(0.95))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    MapTabView()
}
