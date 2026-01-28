//
//  IdleItemModels.swift
//  earthlord
//
//  闲置物品交换数据模型
//  包含物品、评论、上传结构体、错误类型
//

import Foundation
import SwiftUI

// MARK: - 物品成色

/// 物品成色枚举
enum ItemCondition: String, Codable, CaseIterable {
    case new = "new"            // 全新
    case likeNew = "like_new"   // 几乎全新
    case good = "good"          // 良好
    case fair = "fair"          // 一般
    case poor = "poor"          // 较差

    /// 显示名称
    var displayName: String {
        switch self {
        case .new: return "全新"
        case .likeNew: return "几乎全新"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }

    /// 对应颜色
    var color: Color {
        switch self {
        case .new: return ApocalypseTheme.success
        case .likeNew: return ApocalypseTheme.info
        case .good: return ApocalypseTheme.primary
        case .fair: return ApocalypseTheme.warning
        case .poor: return ApocalypseTheme.danger
        }
    }
}

// MARK: - 物品状态

/// 闲置物品状态
enum IdleItemStatus: String, Codable, CaseIterable {
    case active = "active"          // 活跃
    case closed = "closed"          // 已下架
    case exchanged = "exchanged"    // 已交换

    /// 显示名称
    var displayName: String {
        switch self {
        case .active: return "上架中"
        case .closed: return "已下架"
        case .exchanged: return "已交换"
        }
    }
}

// MARK: - 闲置物品

/// 闲置物品模型（对应数据库 idle_items 表）
struct IdleItem: Identifiable, Codable {
    let id: UUID
    let ownerId: UUID
    let ownerUsername: String
    var title: String
    var description: String
    var condition: ItemCondition
    var desiredExchange: String?
    var photoUrls: [String]
    var status: IdleItemStatus
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case title, description, condition
        case desiredExchange = "desired_exchange"
        case photoUrls = "photo_urls"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - 上传结构体

/// 创建闲置物品用
struct IdleItemUpload: Codable {
    let ownerId: UUID
    let ownerUsername: String
    let title: String
    let description: String
    let condition: String
    let desiredExchange: String?
    let photoUrls: [String]
    let status: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case title, description, condition
        case desiredExchange = "desired_exchange"
        case photoUrls = "photo_urls"
        case status
    }
}

// MARK: - 评论

/// 闲置物品评论模型（对应数据库 idle_item_comments 表）
struct IdleItemComment: Identifiable, Codable {
    let id: UUID
    let itemId: UUID
    let userId: UUID
    let username: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case userId = "user_id"
        case username, content
        case createdAt = "created_at"
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// 评论上传结构体
struct IdleItemCommentUpload: Codable {
    let itemId: UUID
    let userId: UUID
    let username: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case userId = "user_id"
        case username, content
    }
}

// MARK: - 交换请求状态

/// 交换请求状态枚举
enum ExchangeRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"

    /// 显示名称
    var displayName: String {
        switch self {
        case .pending: return "等待回复"
        case .accepted: return "已接受"
        case .rejected: return "已拒绝"
        }
    }
}

// MARK: - 交换请求

/// 交换请求模型（对应数据库 idle_item_requests 表）
struct ExchangeRequest: Identifiable, Codable {
    let id: UUID
    let itemId: UUID
    let requesterId: UUID
    let requesterUsername: String
    let message: String?
    let status: ExchangeRequestStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case requesterId = "requester_id"
        case requesterUsername = "requester_username"
        case message, status
        case createdAt = "created_at"
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// 交换请求上传结构体
struct ExchangeRequestUpload: Codable {
    let itemId: UUID
    let requesterId: UUID
    let requesterUsername: String
    let message: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case requesterId = "requester_id"
        case requesterUsername = "requester_username"
        case message
    }
}

// MARK: - 错误类型

/// 闲置物品错误
enum IdleItemError: Error, LocalizedError {
    case notAuthenticated
    case titleRequired
    case descriptionRequired
    case photoRequired
    case tooManyPhotos
    case photoUploadFailed(String)
    case itemNotFound
    case serverError(String)
    case commentTooLong
    case commentEmpty
    case requestAlreadySent
    case requestMessageTooLong
    case cannotRequestOwnItem
    case itemNotActive

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .titleRequired:
            return "请输入物品标题"
        case .descriptionRequired:
            return "请输入物品描述"
        case .photoRequired:
            return "请至少上传一张照片"
        case .tooManyPhotos:
            return "最多上传3张照片"
        case .photoUploadFailed(let message):
            return "照片上传失败：\(message)"
        case .itemNotFound:
            return "物品不存在"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .commentTooLong:
            return "评论不能超过300字"
        case .commentEmpty:
            return "请输入评论内容"
        case .requestAlreadySent:
            return "您已发送过交换请求"
        case .requestMessageTooLong:
            return "附言不能超过200字"
        case .cannotRequestOwnItem:
            return "不能对自己的物品发起交换请求"
        case .itemNotActive:
            return "该物品已下架或已交换"
        }
    }
}
