//
//  IAPProducts.swift
//  earthlord
//
//  内购商品 ID 常量和元数据定义
//

import Foundation

// MARK: - 商品 ID 常量

enum IAPProductID {
    // 订阅
    static let eliteMonthly = "com.earthlord.elite.monthly"
    static let eliteAnnual = "com.earthlord.elite.annual"

    // 消耗品
    static let resourceBox = "com.earthlord.resource_box"
    static let instantBuild = "com.earthlord.instant_build"
    static let explorationBoost = "com.earthlord.exploration_boost"
    static let legendaryCrate = "com.earthlord.legendary_crate"

    /// 所有商品 ID
    static let allProductIDs: Set<String> = [
        eliteMonthly, eliteAnnual,
        resourceBox, instantBuild, explorationBoost, legendaryCrate
    ]

    /// 订阅商品 ID
    static let subscriptionIDs: Set<String> = [
        eliteMonthly, eliteAnnual
    ]

    /// 消耗品商品 ID
    static let consumableIDs: Set<String> = [
        resourceBox, instantBuild, explorationBoost, legendaryCrate
    ]
}

// MARK: - 商品元数据

struct IAPProductMeta {
    let productId: String
    let icon: String          // SF Symbol 名称
    let displayName: String
    let shortDescription: String
    let contents: [String]    // 商品包含内容描述
    let fallbackPrice: String // StoreKit 未加载时显示的回退价格

    /// 所有商品元数据
    static let all: [String: IAPProductMeta] = [
        IAPProductID.eliteMonthly: IAPProductMeta(
            productId: IAPProductID.eliteMonthly,
            icon: "crown.fill",
            displayName: "精英幸存者（月）",
            shortDescription: "解锁所有高级特权",
            contents: [
                "无限探索次数",
                "无限圈地次数",
                "背包扩容至 50kg/40L",
                "建造速度 2 倍",
                "探索奖励 1.5 倍",
                "通讯范围 +20%",
                "交易零手续费"
            ],
            fallbackPrice: "¥25"
        ),
        IAPProductID.eliteAnnual: IAPProductMeta(
            productId: IAPProductID.eliteAnnual,
            icon: "crown.fill",
            displayName: "精英幸存者（年）",
            shortDescription: "年付更划算，约 66 折",
            contents: [
                "包含月订阅所有特权",
                "年付约 66 折优惠"
            ],
            fallbackPrice: "¥198"
        ),
        IAPProductID.resourceBox: IAPProductMeta(
            productId: IAPProductID.resourceBox,
            icon: "shippingbox.fill",
            displayName: "资源补给箱",
            shortDescription: "基础建筑材料大礼包",
            contents: [
                "木材 x50",
                "石头 x50",
                "金属板 x30",
                "电子元件 x20"
            ],
            fallbackPrice: "¥6"
        ),
        IAPProductID.instantBuild: IAPProductMeta(
            productId: IAPProductID.instantBuild,
            icon: "bolt.fill",
            displayName: "即时建造卡",
            shortDescription: "立即完成一个建筑",
            contents: [
                "立即完成当前建造/升级"
            ],
            fallbackPrice: "¥12"
        ),
        IAPProductID.explorationBoost: IAPProductMeta(
            productId: IAPProductID.explorationBoost,
            icon: "arrow.up.circle.fill",
            displayName: "探索增幅器",
            shortDescription: "24 小时探索奖励翻倍",
            contents: [
                "24 小时内探索奖励 x2",
                "与订阅叠加可达 x3"
            ],
            fallbackPrice: "¥18"
        ),
        IAPProductID.legendaryCrate: IAPProductMeta(
            productId: IAPProductID.legendaryCrate,
            icon: "star.circle.fill",
            displayName: "传奇物资箱",
            shortDescription: "3 个传奇级 AI 物品",
            contents: [
                "3 个传奇级 AI 生成物品",
                "独特故事背景"
            ],
            fallbackPrice: "¥25"
        )
    ]
}

// MARK: - 资源补给箱内容定义

struct ResourceBoxContents {
    static let items: [(name: String, quantity: Int)] = [
        ("木材", 50),
        ("石头", 50),
        ("金属板", 30),
        ("电子元件", 20)
    ]
}
