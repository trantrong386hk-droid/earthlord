//
//  CommunicationManager.swift
//  earthlord
//
//  通讯系统管理器
//  负责设备管理、切换、解锁等操作
//

import Foundation
import Combine
import Supabase
import Realtime
import CoreLocation

@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - 单例

    static let shared = CommunicationManager()

    // MARK: - 发布属性

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private let client = supabase

    // MARK: - 初始化

    private init() {
        print("📡 [CommunicationManager] 初始化")
    }

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }

            print("📡 [通讯] ✅ 加载了 \(devices.count) 个设备")
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("📡 [通讯] ❌ 加载失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            try await client
                .rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString])
                .execute()

            await loadDevices(userId: userId)
            print("📡 [通讯] ✅ 设备初始化完成")
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
            print("📡 [通讯] ❌ 初始化失败: \(error)")
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await client
                .rpc("switch_current_device", params: [
                    "p_user_id": userId.uuidString,
                    "p_device_type": deviceType.rawValue
                ])
                .execute()

            // 更新本地状态
            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })

            print("📡 [通讯] ✅ 已切换到 \(deviceType.displayName)")
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
            print("📡 [通讯] ❌ 切换失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            // 更新本地状态
            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }

            print("📡 [通讯] ✅ 已解锁 \(deviceType.displayName)")
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
            print("📡 [通讯] ❌ 解锁失败: \(error)")
        }
    }

    // MARK: - 便捷方法

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 当前设备是否可以发送消息
    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    /// 获取当前设备通讯范围
    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    /// 检查设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 频道属性

    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - 加载公开频道

    func loadPublicChannels() async {
        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
            print("📡 [频道] ✅ 加载了 \(channels.count) 个公开频道")
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
            print("📡 [频道] ❌ 加载失败: \(error)")
        }
    }

    // MARK: - 加载我的订阅频道

    func loadSubscribedChannels(userId: UUID) async {
        do {
            // 先加载订阅记录
            let subscriptions: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            // 如果有订阅，加载对应的频道信息
            if !subscriptions.isEmpty {
                let channelIds = subscriptions.map { $0.channelId.uuidString }
                let channelList: [CommunicationChannel] = try await client
                    .from("communication_channels")
                    .select()
                    .in("id", values: channelIds)
                    .execute()
                    .value

                // 组合订阅和频道信息
                subscribedChannels = subscriptions.compactMap { sub in
                    guard let channel = channelList.first(where: { $0.id == sub.channelId }) else {
                        return nil
                    }
                    return SubscribedChannel(channel: channel, subscription: sub)
                }
            } else {
                subscribedChannels = []
            }

            print("📡 [频道] ✅ 加载了 \(subscribedChannels.count) 个订阅频道")
        } catch {
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
            print("📡 [频道] ❌ 加载订阅失败: \(error)")
        }
    }

    // MARK: - 创建频道

    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async -> CommunicationChannel? {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(type.rawValue),
                "p_name": .string(name),
                "p_description": description.map { .string($0) } ?? .null
            ]

            let response: UUID = try await client
                .rpc("create_channel_with_subscription", params: params)
                .execute()
                .value

            // 重新加载频道列表
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            print("📡 [频道] ✅ 创建频道成功: \(name)")
            isLoading = false

            // 返回新创建的频道
            return channels.first(where: { $0.id == response })
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            print("📡 [频道] ❌ 创建失败: \(error)")
            isLoading = false
            return nil
        }
    }

    // MARK: - 订阅频道

    func subscribeToChannel(userId: UUID, channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            let _: Bool = try await client
                .rpc("subscribe_to_channel", params: params)
                .execute()
                .value

            // 重新加载
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            print("📡 [频道] ✅ 订阅成功")
            isLoading = false
            return true
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
            print("📡 [频道] ❌ 订阅失败: \(error)")
            isLoading = false
            return false
        }
    }

    // MARK: - 取消订阅

    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            let _: Bool = try await client
                .rpc("unsubscribe_from_channel", params: params)
                .execute()
                .value

            // 重新加载
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            print("📡 [频道] ✅ 取消订阅成功")
            isLoading = false
            return true
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            print("📡 [频道] ❌ 取消订阅失败: \(error)")
            isLoading = false
            return false
        }
    }

    // MARK: - 检查是否已订阅

    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains(where: { $0.channelId == channelId })
    }

    // MARK: - 删除频道

    func deleteChannel(channelId: UUID, userId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await client
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .eq("creator_id", value: userId.uuidString)
                .execute()

            // 重新加载
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            print("📡 [频道] ✅ 删除频道成功")
            isLoading = false
            return true
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
            print("📡 [频道] ❌ 删除失败: \(error)")
            isLoading = false
            return false
        }
    }

    // MARK: - 消息相关属性

    @Published private(set) var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published private(set) var isSendingMessage = false
    @Published private(set) var subscribedChannelIds: Set<UUID> = []

    // MARK: - Realtime 相关属性

    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?

    // MARK: - 加载频道历史消息

    func loadChannelMessages(channelId: UUID) async {
        do {
            let response: [ChannelMessage] = try await client
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            channelMessages[channelId] = response
            print("📡 [消息] ✅ 加载了 \(response.count) 条消息")
            for msg in response {
                print("📡 [消息] - senderId: \(msg.senderId?.uuidString ?? "nil"), content: \(msg.content.prefix(20))")
            }
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
            print("📡 [消息] ❌ 加载失败: \(error)")
        }
    }

    // MARK: - 发送消息

    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        isSendingMessage = true
        errorMessage = nil

        do {
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content)
            ]

            if let lat = latitude, let lon = longitude {
                params["p_latitude"] = .double(lat)
                params["p_longitude"] = .double(lon)
            }

            if let device = deviceType {
                params["p_device_type"] = .string(device)
            }

            // 执行 RPC，不解析返回值
            try await client
                .rpc("send_channel_message", params: params)
                .execute()

            // 发送成功后重新加载消息
            await loadChannelMessages(channelId: channelId)

            print("📡 [消息] ✅ 消息发送成功")
            isSendingMessage = false
            return true
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            print("📡 [消息] ❌ 发送失败: \(error)")
            isSendingMessage = false
            return false
        }
    }

    // MARK: - 启动 Realtime 订阅

    func startRealtimeSubscription() {
        guard realtimeChannel == nil else {
            print("📡 [Realtime] 已有活跃订阅")
            return
        }

        let channel = client.realtimeV2.channel("channel_messages_changes")

        messageSubscriptionTask = Task {
            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "channel_messages"
            )

            do {
                try await channel.subscribeWithError()
                print("📡 [Realtime] ✅ 订阅已启动")
            } catch {
                print("📡 [Realtime] ❌ 订阅失败: \(error)")
                return
            }

            for await insertion in insertions {
                await handleNewMessage(insertion: insertion)
            }
        }

        realtimeChannel = channel
    }

    // MARK: - 停止 Realtime 订阅

    func stopRealtimeSubscription() {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            Task {
                await channel.unsubscribe()
                print("📡 [Realtime] ✅ 订阅已停止")
            }
        }
        realtimeChannel = nil
    }

    // MARK: - 处理新消息

    private func handleNewMessage(insertion: InsertAction) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(insertion.record)
            let decoder = JSONDecoder()
            let message = try decoder.decode(ChannelMessage.self, from: data)

            // 检查是否是已订阅的频道
            guard subscribedChannelIds.contains(message.channelId) else {
                return
            }

            // 距离过滤（只对公共频道）
            let channelType = channels.first(where: { $0.id == message.channelId })?.channelType ?? .public
            guard shouldReceiveMessage(message, channelType: channelType) else {
                return
            }

            await MainActor.run {
                if var messages = channelMessages[message.channelId] {
                    // 避免重复添加
                    if !messages.contains(where: { $0.messageId == message.messageId }) {
                        messages.append(message)
                        channelMessages[message.channelId] = messages
                    }
                } else {
                    channelMessages[message.channelId] = [message]
                }
            }
            print("📡 [Realtime] 📩 收到新消息: \(message.content.prefix(20))..., senderId: \(message.senderId?.uuidString ?? "nil")")
        } catch {
            print("📡 [Realtime] ❌ 解析消息失败: \(error)")
        }
    }

    // MARK: - 订阅频道消息（添加到监听列表）

    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        print("📡 [消息] 开始监听频道: \(channelId)")
    }

    // MARK: - 取消订阅频道消息

    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        print("📡 [消息] 停止监听频道: \(channelId)")
    }

    // MARK: - 获取消息列表

    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - 频道成员管理

    @Published private(set) var channelMembers: [UUID: [ChannelMember]] = [:] // channelId -> members

    /// 加载频道成员列表
    func loadChannelMembers(channelId: UUID, creatorId: UUID) async -> [ChannelMember] {
        do {
            // 查询订阅记录并联表获取用户信息
            let response: [[String: AnyJSON]] = try await client
                .from("channel_subscriptions")
                .select("""
                    id,
                    user_id,
                    joined_at,
                    communication_devices!inner(device_type),
                    profiles!inner(callsign)
                """)
                .eq("channel_id", value: channelId.uuidString)
                .eq("communication_devices.is_current", value: true)
                .order("joined_at", ascending: true)
                .execute()
                .value

            // 解析为 ChannelMember
            let members = response.compactMap { dict -> ChannelMember? in
                guard let idStr = dict["id"]?.stringValue,
                      let id = UUID(uuidString: idStr),
                      let userIdStr = dict["user_id"]?.stringValue,
                      let userId = UUID(uuidString: userIdStr),
                      let joinedAtStr = dict["joined_at"]?.stringValue else {
                    return nil
                }

                // 使用 ChannelMessage 的日期解析逻辑
                let joinedAt = parseMessageDate(joinedAtStr) ?? Date()

                let callsign = dict["profiles"]?.objectValue?["callsign"]?.stringValue
                let deviceTypeStr = dict["communication_devices"]?.objectValue?["device_type"]?.stringValue
                let deviceType = deviceTypeStr.flatMap { DeviceType(rawValue: $0) }
                let isCreator = userId == creatorId

                return ChannelMember(
                    id: id,
                    userId: userId,
                    callsign: callsign,
                    deviceType: deviceType,
                    joinedAt: joinedAt,
                    isCreator: isCreator
                )
            }

            // 缓存结果
            channelMembers[channelId] = members

            print("📡 [频道成员] ✅ 加载了 \(members.count) 个成员")
            return members
        } catch {
            errorMessage = "加载成员失败: \(error.localizedDescription)"
            print("📡 [频道成员] ❌ 加载失败: \(error)")
            return []
        }
    }

    /// 解析消息日期（复用 ChannelMessage 的逻辑）
    private func parseMessageDate(_ string: String) -> Date? {
        // ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // 尝试多种格式
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    // MARK: - 距离过滤逻辑

    /// 判断是否应该接收该消息（基于设备类型和距离）
    /// 只对公共频道应用距离过滤
    func shouldReceiveMessage(_ message: ChannelMessage, channelType: ChannelType) -> Bool {
        // 私有频道不限制距离
        guard channelType == .public else {
            return true
        }

        // 1. 获取当前用户设备类型
        guard let myDeviceType = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示消息")
            return true  // 保守策略
        }

        // 2. 收音机可以接收所有消息
        if myDeviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 3. 检查发送者设备类型
        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示")
            return true  // 向后兼容
        }

        // 4. 收音机不能发送
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 5. 检查发送者位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示")
            return true
        }

        // 6. 获取当前用户位置
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true
        }

        // 7. 计算距离
        let distance = calculateDistance(
            from: CLLocationCoordinate2D(latitude: myLocation.latitude, longitude: myLocation.longitude),
            to: CLLocationCoordinate2D(latitude: senderLocation.latitude, longitude: senderLocation.longitude)
        )

        // 8. 根据设备矩阵判断
        let canReceive = canReceiveMessage(senderDevice: senderDevice, myDevice: myDeviceType, distance: distance)

        if canReceive {
            print("✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        } else {
            print("🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        }

        return canReceive
    }

    /// 根据设备类型矩阵判断是否能接收消息
    private func canReceiveMessage(senderDevice: DeviceType, myDevice: DeviceType, distance: Double) -> Bool {
        // 收音机接收方：无距离限制
        if myDevice == .radio {
            return true
        }

        // 收音机发送方：不能发送
        if senderDevice == .radio {
            return false
        }

        // 设备矩阵
        switch (senderDevice, myDevice) {
        // 对讲机发送（3km覆盖）
        case (.walkieTalkie, .walkieTalkie): return distance <= 3.0
        case (.walkieTalkie, .campRadio): return distance <= 30.0
        case (.walkieTalkie, .satellite): return distance <= 100.0

        // 营地电台发送（30km覆盖）
        case (.campRadio, .walkieTalkie): return distance <= 30.0
        case (.campRadio, .campRadio): return distance <= 30.0
        case (.campRadio, .satellite): return distance <= 100.0

        // 卫星通讯发送（100km覆盖）
        case (.satellite, .walkieTalkie): return distance <= 100.0
        case (.satellite, .campRadio): return distance <= 100.0
        case (.satellite, .satellite): return distance <= 100.0

        default: return false
        }
    }

    /// 计算两个坐标之间的距离（公里）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0  // 转换为公里
    }

    /// 获取当前用户位置（从 LocationManager 获取真实 GPS）
    private func getCurrentLocation() -> LocationPoint? {
        guard let coordinate = LocationManager.shared.userLocation else {
            print("⚠️ [距离过滤] LocationManager 无位置数据")
            return nil
        }
        return LocationPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
