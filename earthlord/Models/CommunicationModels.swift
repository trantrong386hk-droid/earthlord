//
//  CommunicationModels.swift
//  earthlord
//
//  通讯系统数据模型
//  包含设备类型、设备模型、导航枚举
//

import Foundation
import SwiftUI

// MARK: - 设备类型

enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "person.wave.2.fill"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "默认拥有"
        case .satellite: return "默认拥有"
        }
    }
}

// MARK: - 设备模型

struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航枚举

enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型

enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case `public` = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道"
        case .public: return "公开频道"
        case .walkie: return "对讲机频道"
        case .camp: return "营地广播"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "megaphone.fill"
        case .public: return "globe"
        case .walkie: return "person.wave.2.fill"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle.fill"
        }
    }

    var codePrefix: String {
        switch self {
        case .official: return "OFF"
        case .public: return "PUB"
        case .walkie: return "WLK"
        case .camp: return "CMP"
        case .satellite: return "SAT"
        }
    }

    var description: String {
        switch self {
        case .official: return "系统官方公告频道"
        case .public: return "所有人可见的公开频道"
        case .walkie: return "需要对讲机设备收听"
        case .camp: return "需要营地电台设备"
        case .satellite: return "需要卫星通讯设备"
        }
    }

    /// 用户可创建的频道类型（排除官方）
    static var userCreatable: [ChannelType] {
        [.public, .walkie, .camp, .satellite]
    }
}

// MARK: - 频道模型

struct CommunicationChannel: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    // 创建者位置（原始 PostGIS 格式）
    private let creatorLocationRaw: String?

    // 解析后的创建者位置
    var creatorLocation: LocationPoint? {
        guard let raw = creatorLocationRaw else { return nil }
        return LocationPoint.fromPostGIS(raw)
    }

    // 自定义初始化器（兼容旧代码）
    init(
        id: UUID,
        creatorId: UUID,
        channelType: ChannelType,
        channelCode: String,
        name: String,
        description: String? = nil,
        isActive: Bool,
        memberCount: Int,
        createdAt: Date,
        updatedAt: Date,
        creatorLocationRaw: String? = nil
    ) {
        self.id = id
        self.creatorId = creatorId
        self.channelType = channelType
        self.channelCode = channelCode
        self.name = name
        self.description = description
        self.isActive = isActive
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creatorLocationRaw = creatorLocationRaw
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case creatorLocationRaw = "creator_location"
    }
}

// MARK: - 订阅模型

struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 组合模型（频道 + 订阅状态）

struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - 位置点模型

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    /// 从 PostGIS POINT 格式解析位置
    /// 格式示例: "POINT(121.4737 31.2304)" 或 "SRID=4326;POINT(121.4737 31.2304)"
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        // 移除 SRID 前缀（如果存在）
        var cleanedWkt = wkt
        if let sridRange = wkt.range(of: "SRID=\\d+;", options: .regularExpression) {
            cleanedWkt = String(wkt[sridRange.upperBound...])
        }

        // 匹配 POINT(lon lat) 格式
        let pattern = "POINT\\s*\\(\\s*([\\d.-]+)\\s+([\\d.-]+)\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: cleanedWkt, options: [], range: NSRange(cleanedWkt.startIndex..., in: cleanedWkt)),
              match.numberOfRanges == 3 else {
            return nil
        }

        guard let lonRange = Range(match.range(at: 1), in: cleanedWkt),
              let latRange = Range(match.range(at: 2), in: cleanedWkt),
              let longitude = Double(cleanedWkt[lonRange]),
              let latitude = Double(cleanedWkt[latRange]) else {
            return nil
        }

        return LocationPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 消息元数据

struct MessageMetadata: Codable {
    let deviceType: String?
    let category: String?  // 消息分类（官方频道专用）
    let messageType: String?  // 消息类型："text" 或 "audio"
    let audioUrl: String?  // 音频文件 URL
    let audioDuration: Double?  // 音频时长（秒）

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
        case messageType = "message_type"
        case audioUrl = "audio_url"
        case audioDuration = "audio_duration"
    }

    init(
        deviceType: String? = nil,
        category: String? = nil,
        messageType: String? = nil,
        audioUrl: String? = nil,
        audioDuration: Double? = nil
    ) {
        self.deviceType = deviceType
        self.category = category
        self.messageType = messageType
        self.audioUrl = audioUrl
        self.audioDuration = audioDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceType = try container.decodeIfPresent(String.self, forKey: .deviceType)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
        audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl)
        audioDuration = try container.decodeIfPresent(Double.self, forKey: .audioDuration)
    }
}

// MARK: - 频道消息模型

struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    private let senderLocationRaw: String?
    let metadata: MessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    /// 解析后的发送者位置
    var senderLocation: LocationPoint? {
        guard let raw = senderLocationRaw else { return nil }
        return LocationPoint.fromPostGIS(raw)
    }

    /// 设备类型字符串
    var deviceType: String? {
        metadata?.deviceType
    }

    /// 发送者设备类型（从 metadata 解析）
    var senderDeviceType: DeviceType? {
        guard let deviceTypeString = metadata?.deviceType else { return nil }
        return DeviceType(rawValue: deviceTypeString)
    }

    /// 显示用的时间（如 "刚刚"、"5分钟前"）
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocationRaw = "sender_location"
        case metadata
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        senderLocationRaw = try container.decodeIfPresent(String.self, forKey: .senderLocationRaw)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // 多格式日期解析
        let dateString = try container.decode(String.self, forKey: .createdAt)
        createdAt = ChannelMessage.parseDate(dateString) ?? Date()
    }

    /// 多格式日期解析
    private static func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }
        }()

        // 尝试 ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // 尝试各种格式
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    /// 用于本地创建（发送时预览）
    init(messageId: UUID, channelId: UUID, senderId: UUID?, senderCallsign: String?, content: String, metadata: MessageMetadata?, createdAt: Date) {
        self.messageId = messageId
        self.channelId = channelId
        self.senderId = senderId
        self.senderCallsign = senderCallsign
        self.content = content
        self.senderLocationRaw = nil
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - 频道成员模型

struct ChannelMember: Identifiable, Codable {
    let id: UUID                  // subscription.id
    let userId: UUID              // 用户ID
    let callsign: String?         // 呼号
    let deviceType: DeviceType?   // 当前设备类型
    let joinedAt: Date            // 加入时间
    let isCreator: Bool           // 是否是频道创建者

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case callsign
        case deviceType = "device_type"
        case joinedAt = "joined_at"
        case isCreator = "is_creator"
    }

    /// 加入时长显示（如 "2天前加入"）
    var joinedTimeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(joinedAt)

        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前加入"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前加入"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前加入"
        }
    }
}

// MARK: - 消息分类（官方频道专用）

enum MessageCategory: String, Codable, CaseIterable {
    case survival = "survival"   // 生存指南
    case news = "news"           // 游戏资讯
    case mission = "mission"     // 任务发布
    case alert = "alert"         // 紧急广播

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news: return "游戏资讯"
        case .mission: return "任务发布"
        case .alert: return "紧急广播"
        }
    }

    var color: Color {
        switch self {
        case .survival: return .green
        case .news: return .blue
        case .mission: return .orange
        case .alert: return .red
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "leaf.fill"
        case .news: return "newspaper.fill"
        case .mission: return "target"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ChannelMessage 扩展

extension ChannelMessage {
    /// 消息分类（从 metadata 中解析）
    var category: MessageCategory? {
        guard let categoryString = metadata?.category else { return nil }
        return MessageCategory(rawValue: categoryString)
    }

    /// 是否是音频消息
    var isAudioMessage: Bool {
        return metadata?.messageType == "audio"
    }

    /// 音频 URL
    var audioUrl: String? {
        return metadata?.audioUrl
    }

    /// 音频时长
    var audioDuration: Double? {
        return metadata?.audioDuration
    }
}
