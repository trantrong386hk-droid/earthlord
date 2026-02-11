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
    static var all: [String: IAPProductMeta] { [
        IAPProductID.eliteMonthly: IAPProductMeta(
            productId: IAPProductID.eliteMonthly,
            icon: "crown.fill",
            displayName: "精英幸存者（月）".localized,
            shortDescription: "解锁所有高级特权".localized,
            contents: [
                "无限探索次数".localized,
                "无限圈地次数".localized,
                "背包扩容至 50kg/40L".localized,
                "建造速度 2 倍".localized,
                "探索奖励 1.5 倍".localized,
                "通讯范围 +20%".localized,
                "交易零手续费".localized
            ],
            fallbackPrice: "¥25"
        ),
        IAPProductID.eliteAnnual: IAPProductMeta(
            productId: IAPProductID.eliteAnnual,
            icon: "crown.fill",
            displayName: "精英幸存者（年）".localized,
            shortDescription: "年付更划算，约 66 折".localized,
            contents: [
                "包含月订阅所有特权".localized,
                "年付约 66 折优惠".localized
            ],
            fallbackPrice: "¥198"
        ),
        IAPProductID.resourceBox: IAPProductMeta(
            productId: IAPProductID.resourceBox,
            icon: "shippingbox.fill",
            displayName: "资源补给箱".localized,
            shortDescription: "基础建筑材料大礼包".localized,
            contents: [
                "木材 x50".localized,
                "石头 x50".localized,
                "金属板 x30".localized,
                "电子元件 x20".localized
            ],
            fallbackPrice: "¥6"
        ),
        IAPProductID.instantBuild: IAPProductMeta(
            productId: IAPProductID.instantBuild,
            icon: "bolt.fill",
            displayName: "即时建造卡".localized,
            shortDescription: "立即完成一个建筑".localized,
            contents: [
                "立即完成当前建造/升级".localized
            ],
            fallbackPrice: "¥12"
        ),
        IAPProductID.explorationBoost: IAPProductMeta(
            productId: IAPProductID.explorationBoost,
            icon: "arrow.up.circle.fill",
            displayName: "探索增幅器".localized,
            shortDescription: "24 小时探索奖励翻倍".localized,
            contents: [
                "24 小时内探索奖励 x2".localized,
                "与订阅叠加可达 x3".localized
            ],
            fallbackPrice: "¥18"
        ),
        IAPProductID.legendaryCrate: IAPProductMeta(
            productId: IAPProductID.legendaryCrate,
            icon: "star.circle.fill",
            displayName: "传奇物资箱".localized,
            shortDescription: "3 个传奇级 AI 物品".localized,
            contents: [
                "3 个传奇级 AI 生成物品".localized,
                "独特故事背景".localized
            ],
            fallbackPrice: "¥25"
        )
    ] }
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
