//
//  IdleItemManager.swift
//  earthlord
//
//  闲置物品管理器
//  负责照片上传、物品 CRUD、评论管理
//

import Foundation
import UIKit
import Combine
import Supabase

// MARK: - IdleItemManager

@MainActor
class IdleItemManager: ObservableObject {

    // MARK: - 单例
    static let shared = IdleItemManager()

    // MARK: - 发布属性

    /// 所有活跃的闲置物品
    @Published var allItems: [IdleItem] = []

    /// 我的闲置物品
    @Published var myItems: [IdleItem] = []

    /// 当前物品的评论
    @Published var comments: [IdleItemComment] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private var currentUserId: UUID?

    // MARK: - 常量

    private let maxPhotoWidth: CGFloat = 1200
    private let initialJPEGQuality: CGFloat = 0.5
    private let fallbackJPEGQuality: CGFloat = 0.3
    private let maxPhotoSize: Int = 500 * 1024 // 500KB
    private let bucketName = "idle-items"

    // MARK: - 初始化

    private init() {
        print("📦 [IdleItemManager] 初始化")
    }

    // MARK: - 照片操作

    /// 上传照片到 Storage
    /// - Parameter image: 要上传的图片
    /// - Returns: 照片在 Storage 中的路径
    func uploadPhoto(_ image: UIImage) async throws -> String {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw IdleItemError.notAuthenticated
        }

        // 1. Resize 图片
        let resized = resizeImage(image, maxWidth: maxPhotoWidth)

        // 2. 压缩为 JPEG
        guard var data = resized.jpegData(compressionQuality: initialJPEGQuality) else {
            throw IdleItemError.photoUploadFailed("图片压缩失败")
        }

        // 3. 如果超过 500KB，再次压缩
        if data.count > maxPhotoSize {
            guard let recompressed = resized.jpegData(compressionQuality: fallbackJPEGQuality) else {
                throw IdleItemError.photoUploadFailed("图片二次压缩失败")
            }
            data = recompressed
        }

        // 4. 生成路径
        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(userId.uuidString)/\(fileName)"

        // 5. 上传到 Storage
        do {
            try await supabase.storage
                .from(bucketName)
                .upload(
                    path: path,
                    file: data,
                    options: FileOptions(contentType: "image/jpeg")
                )
            print("📦 [照片] ✅ 上传成功: \(path)")
            return path
        } catch {
            print("📦 [照片] ❌ 上传失败: \(error)")
            throw IdleItemError.photoUploadFailed(error.localizedDescription)
        }
    }

    /// 获取照片签名 URL
    /// - Parameter path: Storage 中的路径
    /// - Returns: 签名 URL
    func getPhotoURL(path: String) async throws -> URL {
        let signedURL = try await supabase.storage
            .from(bucketName)
            .createSignedURL(path: path, expiresIn: 3600)
        return signedURL
    }

    /// 删除照片
    /// - Parameter path: Storage 中的路径
    func deletePhoto(path: String) async throws {
        try await supabase.storage
            .from(bucketName)
            .remove(paths: [path])
        print("📦 [照片] ✅ 删除成功: \(path)")
    }

    // MARK: - CRUD 操作

    /// 创建闲置物品
    @discardableResult
    func createItem(
        title: String,
        description: String,
        condition: ItemCondition,
        desiredExchange: String?,
        photoUrls: [String]
    ) async throws -> IdleItem {
        print("📦 [闲置] 开始创建物品...")

        // 验证
        guard let userId = try? await supabase.auth.session.user.id else {
            throw IdleItemError.notAuthenticated
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IdleItemError.titleRequired
        }

        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDesc.isEmpty else {
            throw IdleItemError.descriptionRequired
        }

        guard !photoUrls.isEmpty else {
            throw IdleItemError.photoRequired
        }

        guard photoUrls.count <= 3 else {
            throw IdleItemError.tooManyPhotos
        }

        let username = AuthManager.shared.userEmail ?? "匿名用户"

        let upload = IdleItemUpload(
            ownerId: userId,
            ownerUsername: username,
            title: trimmedTitle,
            description: trimmedDesc,
            condition: condition.rawValue,
            desiredExchange: desiredExchange?.trimmingCharacters(in: .whitespacesAndNewlines),
            photoUrls: photoUrls,
            status: "active"
        )

        do {
            let item: IdleItem = try await supabase
                .from("idle_items")
                .insert(upload)
                .select()
                .single()
                .execute()
                .value

            allItems.insert(item, at: 0)
            myItems.insert(item, at: 0)

            print("📦 [闲置] ✅ 物品创建成功: \(item.id)")
            return item
        } catch {
            print("📦 [闲置] ❌ 物品创建失败: \(error)")
            throw IdleItemError.serverError(error.localizedDescription)
        }
    }

    /// 加载所有活跃物品
    func loadAllItems() async {
        print("📦 [闲置] 加载所有活跃物品...")
        isLoading = true
        errorMessage = nil

        do {
            let items: [IdleItem] = try await supabase
                .from("idle_items")
                .select()
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .execute()
                .value

            allItems = items
            print("📦 [闲置] ✅ 加载了 \(items.count) 个活跃物品")
        } catch {
            errorMessage = error.localizedDescription
            print("📦 [闲置] ❌ 加载失败: \(error)")
        }

        isLoading = false
    }

    /// 加载我的物品
    func loadMyItems() async {
        print("📦 [闲置] 加载我的物品...")

        guard let userId = try? await supabase.auth.session.user.id else {
            print("📦 [闲置] 用户未登录")
            return
        }
        currentUserId = userId

        do {
            let items: [IdleItem] = try await supabase
                .from("idle_items")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myItems = items
            print("📦 [闲置] ✅ 加载了 \(items.count) 个我的物品")
        } catch {
            print("📦 [闲置] ❌ 加载我的物品失败: \(error)")
        }
    }

    /// 下架物品
    func closeItem(itemId: UUID) async throws {
        print("📦 [闲置] 下架物品: \(itemId)")

        try await supabase
            .from("idle_items")
            .update(["status": "closed"])
            .eq("id", value: itemId.uuidString)
            .execute()

        updateLocalItemStatus(itemId: itemId, status: .closed)
        print("📦 [闲置] ✅ 已下架")
    }

    /// 标记已交换
    func markExchanged(itemId: UUID) async throws {
        print("📦 [闲置] 标记已交换: \(itemId)")

        try await supabase
            .from("idle_items")
            .update(["status": "exchanged"])
            .eq("id", value: itemId.uuidString)
            .execute()

        updateLocalItemStatus(itemId: itemId, status: .exchanged)
        print("📦 [闲置] ✅ 已标记交换")
    }

    /// 删除物品（含照片）
    func deleteItem(itemId: UUID) async throws {
        print("📦 [闲置] 删除物品: \(itemId)")

        // 找到物品获取照片路径
        let item = allItems.first(where: { $0.id == itemId })
            ?? myItems.first(where: { $0.id == itemId })

        // 删除数据库记录
        try await supabase
            .from("idle_items")
            .delete()
            .eq("id", value: itemId.uuidString)
            .execute()

        // 删除照片
        if let photos = item?.photoUrls {
            for path in photos {
                try? await deletePhoto(path: path)
            }
        }

        // 更新本地
        allItems.removeAll { $0.id == itemId }
        myItems.removeAll { $0.id == itemId }

        print("📦 [闲置] ✅ 已删除")
    }

    // MARK: - 评论操作

    /// 加载评论列表
    func loadComments(itemId: UUID) async {
        print("📦 [评论] 加载评论: \(itemId)")

        do {
            let result: [IdleItemComment] = try await supabase
                .from("idle_item_comments")
                .select()
                .eq("item_id", value: itemId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            comments = result
            print("📦 [评论] ✅ 加载了 \(result.count) 条评论")
        } catch {
            print("📦 [评论] ❌ 加载失败: \(error)")
        }
    }

    /// 添加评论
    @discardableResult
    func addComment(itemId: UUID, content: String) async throws -> IdleItemComment {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IdleItemError.commentEmpty
        }
        guard trimmed.count <= 300 else {
            throw IdleItemError.commentTooLong
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw IdleItemError.notAuthenticated
        }

        let username = AuthManager.shared.userEmail ?? "匿名用户"

        let upload = IdleItemCommentUpload(
            itemId: itemId,
            userId: userId,
            username: username,
            content: trimmed
        )

        let comment: IdleItemComment = try await supabase
            .from("idle_item_comments")
            .insert(upload)
            .select()
            .single()
            .execute()
            .value

        comments.append(comment)
        print("📦 [评论] ✅ 评论添加成功")
        return comment
    }

    /// 删除评论
    func deleteComment(commentId: UUID) async throws {
        try await supabase
            .from("idle_item_comments")
            .delete()
            .eq("id", value: commentId.uuidString)
            .execute()

        comments.removeAll { $0.id == commentId }
        print("📦 [评论] ✅ 评论已删除")
    }

    // MARK: - 辅助方法

    /// 获取当前用户 ID
    func getCurrentUserId() async -> UUID? {
        if let cached = currentUserId {
            return cached
        }
        currentUserId = try? await supabase.auth.session.user.id
        return currentUserId
    }

    /// 更新本地物品状态
    private func updateLocalItemStatus(itemId: UUID, status: IdleItemStatus) {
        if let index = allItems.firstIndex(where: { $0.id == itemId }) {
            allItems[index].status = status
        }
        if let index = myItems.firstIndex(where: { $0.id == itemId }) {
            myItems[index].status = status
        }
        // 如果下架/交换，从 allItems 移除（只保留 active）
        if status != .active {
            allItems.removeAll { $0.id == itemId }
        }
    }

    /// 缩放图片到最大宽度
    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }

        let scale = maxWidth / image.size.width
        let newSize = CGSize(
            width: maxWidth,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
