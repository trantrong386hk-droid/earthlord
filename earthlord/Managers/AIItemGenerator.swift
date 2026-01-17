//
//  AIItemGenerator.swift
//  earthlord
//
//  AI 物品生成器
//  通过 Supabase Edge Function 调用阿里云百炼 qwen-flash 模型
//  生成具有独特名称和背景故事的物品
//

import Foundation
import Supabase

// MARK: - AI 生成的物品

/// AI 生成的物品
struct AIGeneratedItem: Codable, Sendable {
    let name: String
    let category: String
    let rarity: String
    let story: String
}

// MARK: - Edge Function 请求/响应

/// Edge Function 响应
struct AIGenerateResponse: Codable, Sendable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}

/// Edge Function 请求
struct AIGenerateRequest: Encodable, Sendable {
    let poi: POIInfo
    let itemCount: Int

    struct POIInfo: Encodable, Sendable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
}

// MARK: - AIItemGenerator

@MainActor
final class AIItemGenerator {

    // MARK: - 单例

    static let shared = AIItemGenerator()

    private init() {
        print("🤖 [AI物品] 初始化")
    }

    // MARK: - 公开方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成物品数量
    /// - Returns: AI 生成的物品数组，失败返回 nil
    func generateItems(for poi: POI, count: Int = 3) async -> [AIGeneratedItem]? {
        print("🤖 [AI物品] 开始生成，POI: \(poi.name)，危险等级: \(poi.dangerLevel)，数量: \(count)")

        let request = AIGenerateRequest(
            poi: .init(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: poi.dangerLevel
            ),
            itemCount: count
        )

        do {
            let response: AIGenerateResponse = try await supabase.functions
                .invoke("generate-ai-item", options: .init(body: request))

            if response.success, let items = response.items {
                print("🤖 [AI物品] ✅ 生成成功，获得 \(items.count) 件物品")
                for (index, item) in items.enumerated() {
                    print("🤖 [AI物品]   \(index + 1). \(item.name) [\(item.rarity)] - \(item.category)")
                }
                return items
            } else {
                print("🤖 [AI物品] ❌ 生成失败: \(response.error ?? "未知错误")")
            }
        } catch {
            print("🤖 [AI物品] ❌ 调用失败: \(error)")
        }

        return nil
    }
}
