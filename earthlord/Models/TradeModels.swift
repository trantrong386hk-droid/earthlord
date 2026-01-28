//
//  TradeModels.swift
//  earthlord
//
//  交易系统数据模型
//  包含交易挂单、交易历史、交易物品等结构
//

import Foundation

// MARK: - 交易状态

/// 交易挂单状态
enum TradeStatus: String, Codable, CaseIterable {
    case active = "active"          // 活跃中
    case completed = "completed"    // 已完成
    case cancelled = "cancelled"    // 已取消
    case expired = "expired"        // 已过期

    /// 显示名称
    var displayName: String {
        switch self {
        case .active:
            return "交易中"
        case .completed:
            return "已完成"
        case .cancelled:
            return "已取消"
        case .expired:
            return "已过期"
        }
    }
}

// MARK: - 交易物品

/// 交易物品（用于挂单中的物品列表）
struct TradeItem: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String      // 物品名称（中文，如"木材"）
    let quantity: Int

    init(name: String, quantity: Int) {
        self.name = name
        self.quantity = quantity
    }
}

// MARK: - 交易挂单

/// 交易挂单（对应数据库 trade_offers 表）
struct TradeOffer: Identifiable, Codable {
    let id: UUID
    let ownerId: UUID
    let ownerUsername: String?
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    var status: TradeStatus
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    var completedAt: Date?
    var completedByUserId: UUID?
    var completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id, status, message
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 是否已过期
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// 是否可以接受（活跃且未过期）
    var canAccept: Bool {
        status == .active && !isExpired
    }

    /// 格式化剩余时间
    var formattedExpiresIn: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        guard remaining > 0 else { return "已过期" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)天后过期"
        } else if hours > 0 {
            return "\(hours)小时\(minutes)分后过期"
        } else if minutes > 0 {
            return "\(minutes)分钟后过期"
        } else {
            return "即将过期"
        }
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - 交易物品交换记录

/// 交易物品交换记录（存储在 trade_history 中）
struct TradeItemsExchanged: Codable {
    let offered: [TradeItem]    // 卖家提供的物品
    let requested: [TradeItem]  // 买家支付的物品
}

// MARK: - 交易历史

/// 交易历史记录（对应数据库 trade_history 表）
struct TradeHistory: Identifiable, Codable {
    let id: UUID
    let offerId: UUID?
    let sellerId: UUID
    let sellerUsername: String?
    let buyerId: UUID
    let buyerUsername: String?
    let itemsExchanged: TradeItemsExchanged
    let completedAt: Date
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 格式化完成时间
    var formattedCompletedAt: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: completedAt)
    }

    /// 获取用户在本次交易中的角色
    func role(for userId: UUID) -> TradeRole? {
        if sellerId == userId {
            return .seller
        } else if buyerId == userId {
            return .buyer
        }
        return nil
    }

    /// 用户是否可以评价
    func canRate(as userId: UUID) -> Bool {
        if sellerId == userId {
            return sellerRating == nil
        } else if buyerId == userId {
            return buyerRating == nil
        }
        return false
    }
}

/// 交易角色
enum TradeRole {
    case seller  // 卖家（挂单发起者）
    case buyer   // 买家（接受挂单者）

    var displayName: String {
        switch self {
        case .seller:
            return "卖家"
        case .buyer:
            return "买家"
        }
    }
}

// MARK: - 上传/更新结构体

/// 创建交易挂单用
struct TradeOfferUpload: Codable {
    let ownerId: UUID
    let ownerUsername: String?
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    let status: String
    let message: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status, message
        case expiresAt = "expires_at"
    }
}

/// 更新交易挂单状态用
struct TradeOfferUpdate: Codable {
    var status: String?
    var completedAt: Date?
    var completedByUserId: UUID?
    var completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }
}

/// 交易评价更新用
struct TradeRatingUpdate: Codable {
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }
}

// MARK: - RPC 返回结果

/// accept_trade_offer RPC 函数返回结果
struct TradeRPCResult: Codable {
    let success: Bool
    let error: String?
}

// MARK: - 交易错误

/// 交易系统错误类型
enum TradeError: Error, LocalizedError {
    case notAuthenticated
    case insufficientItems(String)
    case offerNotFound
    case offerExpired
    case offerNotActive
    case cannotAcceptOwnOffer
    case alreadyRated
    case serverError(String)
    case invalidItems

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .insufficientItems(let message):
            return "物品不足：\(message)"
        case .offerNotFound:
            return "交易挂单不存在"
        case .offerExpired:
            return "交易挂单已过期"
        case .offerNotActive:
            return "交易挂单已失效"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .alreadyRated:
            return "已经评价过了"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .invalidItems:
            return "物品列表无效"
        }
    }
}

// MARK: - 通知定义

extension Notification.Name {
    /// 交易挂单创建成功
    static let tradeOfferCreated = Notification.Name("tradeOfferCreated")
    /// 交易完成
    static let tradeCompleted = Notification.Name("tradeCompleted")
    /// 交易挂单取消
    static let tradeOfferCancelled = Notification.Name("tradeOfferCancelled")
}
