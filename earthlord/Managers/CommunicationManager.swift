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
