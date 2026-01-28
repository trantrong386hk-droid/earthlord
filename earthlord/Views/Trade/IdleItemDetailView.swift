//
//  IdleItemDetailView.swift
//  earthlord
//
//  闲置物品详情页
//  照片轮播 + 物品信息 + 操作按钮 + 评论区
//

import SwiftUI

struct IdleItemDetailView: View {

    // MARK: - 属性

    let item: IdleItem

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var idleManager = IdleItemManager.shared

    // MARK: - 状态

    @State private var photoURLs: [URL] = []
    @State private var currentPhotoIndex: Int = 0
    @State private var isOwner = false
    @State private var commentText: String = ""
    @State private var isSendingComment = false
    @State private var showDeleteConfirm = false
    @State private var showActionError = false
    @State private var actionErrorMessage = ""
    @State private var isPerformingAction = false
    @State private var currentUserId: UUID?

    // 交换请求相关
    @State private var showRequestSheet = false
    @State private var requestMessage: String = ""
    @State private var isSendingRequest = false
    @State private var hasRequested = false
    @State private var showAcceptConfirm = false
    @State private var pendingAcceptRequestId: UUID?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 照片轮播
                            photoCarousel

                            // 物品信息
                            itemInfoCard

                            // 操作按钮（仅物主可见）
                            if isOwner && item.status == .active {
                                ownerActions
                            }

                            // 物主：交换请求列表
                            if isOwner && item.status == .active {
                                exchangeRequestsSection
                            }

                            // 非物主：交换请求按钮
                            if !isOwner && item.status == .active {
                                exchangeRequestButton
                            }

                            // 评论区
                            commentsSection
                        }
                        .padding(16)
                        .padding(.bottom, 80) // 为底部输入栏留空间
                    }

                    // 底部评论输入
                    commentInputBar
                }
            }
            .navigationTitle("物品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .task {
                await loadData()
            }
            .alert("操作失败", isPresented: $showActionError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(actionErrorMessage)
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    deleteItem()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复，照片也将被删除")
            }
            .alert("确认接受交换", isPresented: $showAcceptConfirm) {
                Button("确认接受", role: .destructive) {
                    if let requestId = pendingAcceptRequestId {
                        acceptRequest(requestId)
                    }
                }
                Button("取消", role: .cancel) {
                    pendingAcceptRequestId = nil
                }
            } message: {
                Text("接受后物品将标记为已交换并自动下架，其他请求将被拒绝")
            }
            .sheet(isPresented: $showRequestSheet) {
                exchangeRequestSheet
            }
        }
    }

    // MARK: - 照片轮播

    private var photoCarousel: some View {
        VStack(spacing: 8) {
            if photoURLs.isEmpty {
                // 加载中
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(height: 260)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    )
            } else {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(photoURLs.indices, id: \.self) { index in
                        AsyncImage(url: photoURLs[index]) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                photoErrorView
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                            @unknown default:
                                photoErrorView
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 260)
                .cornerRadius(12)
            }

            // 页码指示
            if photoURLs.count > 1 {
                Text("\(currentPhotoIndex + 1)/\(photoURLs.count)")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    private var photoErrorView: some View {
        ZStack {
            ApocalypseTheme.cardBackground
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(ApocalypseTheme.textMuted)
                Text("加载失败")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - 物品信息

    private var itemInfoCard: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 成色 + 发布者 + 时间
                HStack(spacing: 10) {
                    // 成色标签
                    Text(item.condition.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(item.condition.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.condition.color.opacity(0.15))
                        )

                    // 发布者
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption2)
                        Text(item.ownerUsername)
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 时间
                    Text(item.formattedCreatedAt)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 描述
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineSpacing(4)

                // 期望交换
                if let desired = item.desiredExchange, !desired.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("期望交换: \(desired)")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .padding(.top, 4)
                }

                // 状态标签（非活跃时显示）
                if item.status != .active {
                    HStack(spacing: 4) {
                        Image(systemName: item.status == .exchanged ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(item.status.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(item.status == .exchanged ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - 物主操作按钮

    private var ownerActions: some View {
        ApocalypseCard(padding: 16) {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("管理物品")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Spacer()
                }

                HStack(spacing: 10) {
                    // 标记已交换
                    Button {
                        markExchanged()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                            Text("已交换")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ApocalypseTheme.success)
                        )
                    }
                    .disabled(isPerformingAction)

                    // 下架
                    Button {
                        closeItem()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.slash")
                            Text("下架")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ApocalypseTheme.warning)
                        )
                    }
                    .disabled(isPerformingAction)

                    // 删除
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("删除")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ApocalypseTheme.danger)
                        )
                    }
                    .disabled(isPerformingAction)
                }
            }
        }
    }

    // MARK: - 交换请求按钮（非物主）

    private var exchangeRequestButton: some View {
        ApocalypseCard(padding: 16) {
            if hasRequested {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("已发送请求，等待回复")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else {
                Button {
                    showRequestSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("我想交换")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.primary)
                    )
                }
            }
        }
    }

    // MARK: - 交换请求列表（物主）

    private var exchangeRequestsSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("交换请求")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    let pendingCount = idleManager.requests.filter { $0.status == .pending }.count
                    if pendingCount > 0 {
                        Text("\(pendingCount)条待处理")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)
                    }
                }

                let pendingRequests = idleManager.requests.filter { $0.status == .pending }

                if pendingRequests.isEmpty {
                    Text("暂无交换请求")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    ForEach(pendingRequests) { request in
                        requestRow(request)

                        if request.id != pendingRequests.last?.id {
                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.2))
                        }
                    }
                }
            }
        }
    }

    private func requestRow(_ request: ExchangeRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(request.requesterUsername)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text(request.formattedCreatedAt)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if let message = request.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineSpacing(2)
            }

            HStack(spacing: 10) {
                Button {
                    pendingAcceptRequestId = request.id
                    showAcceptConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("接受")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.success)
                    )
                }
                .disabled(isPerformingAction)

                Button {
                    rejectRequest(request.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("拒绝")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.danger)
                    )
                }
                .disabled(isPerformingAction)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 交换请求 Sheet

    private var exchangeRequestSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("想交换: \(item.title)")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("给物主留言（可选，最多200字）")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $requestMessage)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100, maxHeight: 160)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ApocalypseTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                        )

                    HStack {
                        Spacer()
                        Text("\(requestMessage.count)/200")
                            .font(.caption2)
                            .foregroundColor(requestMessage.count > 200 ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                    }

                    Button {
                        sendExchangeRequest()
                    } label: {
                        if isSendingRequest {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("发送交换请求")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(requestMessage.count > 200 ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
                    )
                    .disabled(isSendingRequest || requestMessage.count > 200)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("发起交换")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showRequestSheet = false
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 评论区

    private var commentsSection: some View {
        ApocalypseCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("评论")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text("(\(idleManager.comments.count)条)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                if idleManager.comments.isEmpty {
                    Text("暂无评论，快来抢沙发吧")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    ForEach(idleManager.comments) { comment in
                        commentRow(comment)

                        if comment.id != idleManager.comments.last?.id {
                            Divider()
                                .background(ApocalypseTheme.textMuted.opacity(0.2))
                        }
                    }
                }
            }
        }
    }

    private func commentRow(_ comment: IdleItemComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(comment.username)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text(comment.formattedCreatedAt)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textMuted)

                // 删除自己的评论
                if comment.userId == currentUserId {
                    Button {
                        deleteComment(comment.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.danger.opacity(0.7))
                    }
                }
            }

            Text(comment.content)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 底部评论输入栏

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            HStack(spacing: 10) {
                TextField("写评论...", text: $commentText)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(ApocalypseTheme.cardBackground)
                    )

                Button {
                    sendComment()
                } label: {
                    if isSendingComment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                }
                .background(
                    Circle()
                        .fill(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? ApocalypseTheme.textMuted
                              : ApocalypseTheme.primary)
                )
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingComment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.background)
        }
    }

    // MARK: - 方法

    private func loadData() async {
        // 加载照片 URL
        var urls: [URL] = []
        for path in item.photoUrls {
            if let url = try? await idleManager.getPhotoURL(path: path) {
                urls.append(url)
            }
        }
        photoURLs = urls

        // 检查是否物主
        currentUserId = await idleManager.getCurrentUserId()
        isOwner = item.ownerId == currentUserId

        // 加载交换请求
        await idleManager.loadRequests(itemId: item.id)

        // 非物主：检查是否已发送请求
        if !isOwner {
            hasRequested = (try? await idleManager.hasUserRequested(itemId: item.id)) ?? false
        }

        // 加载评论
        await idleManager.loadComments(itemId: item.id)
    }

    private func sendComment() {
        let text = commentText
        commentText = ""
        isSendingComment = true

        Task {
            do {
                try await idleManager.addComment(itemId: item.id, content: text)
                await MainActor.run {
                    isSendingComment = false
                }
            } catch {
                await MainActor.run {
                    isSendingComment = false
                    commentText = text // 恢复文本
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }

    private func deleteComment(_ commentId: UUID) {
        Task {
            do {
                try await idleManager.deleteComment(commentId: commentId)
            } catch {
                actionErrorMessage = error.localizedDescription
                showActionError = true
            }
        }
    }

    private func markExchanged() {
        isPerformingAction = true
        Task {
            do {
                try await idleManager.markExchanged(itemId: item.id)
                await MainActor.run {
                    isPerformingAction = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }

    private func closeItem() {
        isPerformingAction = true
        Task {
            do {
                try await idleManager.closeItem(itemId: item.id)
                await MainActor.run {
                    isPerformingAction = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }

    private func sendExchangeRequest() {
        isSendingRequest = true
        let message = requestMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                try await idleManager.sendRequest(
                    itemId: item.id,
                    message: message.isEmpty ? nil : message
                )
                await MainActor.run {
                    isSendingRequest = false
                    hasRequested = true
                    showRequestSheet = false
                    requestMessage = ""
                }
            } catch {
                await MainActor.run {
                    isSendingRequest = false
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }

    private func acceptRequest(_ requestId: UUID) {
        isPerformingAction = true
        Task {
            do {
                try await idleManager.acceptRequest(requestId: requestId)
                await MainActor.run {
                    isPerformingAction = false
                    pendingAcceptRequestId = nil
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    pendingAcceptRequestId = nil
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }

    private func rejectRequest(_ requestId: UUID) {
        isPerformingAction = true
        Task {
            do {
                try await idleManager.rejectRequest(requestId: requestId)
                await MainActor.run {
                    isPerformingAction = false
                }
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }

    private func deleteItem() {
        isPerformingAction = true
        Task {
            do {
                try await idleManager.deleteItem(itemId: item.id)
                await MainActor.run {
                    isPerformingAction = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPerformingAction = false
                    actionErrorMessage = error.localizedDescription
                    showActionError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    IdleItemDetailView(
        item: IdleItem(
            id: UUID(),
            ownerId: UUID(),
            ownerUsername: "test@example.com",
            title: "测试物品",
            description: "这是一个测试物品的描述",
            condition: .good,
            desiredExchange: "期望交换一些有趣的东西",
            photoUrls: [],
            status: .active,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
