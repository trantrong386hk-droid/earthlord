//
//  AuthManager.swift
//  earthlord
//
//  EarthLord 游戏认证管理器
//  负责用户注册、登录、找回密码等认证流程
//

import Foundation
import Combine
import Supabase
import Auth
#if os(iOS)
import UIKit
#endif

// MARK: - 认证流程类型
/// 用于区分当前正在进行的认证流程
enum AuthFlowType {
    case none           // 无流程
    case register       // 注册流程
    case resetPassword  // 找回密码流程
}

// MARK: - 认证管理器
/// 管理所有用户认证相关的状态和操作
///
/// ## 认证流程说明：
/// - **注册**：发验证码 → 验证（已登录但无密码）→ 强制设置密码 → 完成
/// - **登录**：邮箱 + 密码（直接登录）
/// - **找回密码**：发验证码 → 验证（已登录）→ 设置新密码 → 完成
///
/// ## 重要提示：
/// `verifyOTP` 成功后用户已登录，但注册流程必须强制设置密码才能进入主页！
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已认证（已登录且完成所有流程）
    /// - 注册流程：OTP验证 + 设置密码后才为 true
    /// - 登录流程：登录成功后为 true
    /// - 找回密码：设置新密码后为 true
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码
    /// - 注册流程：OTP验证后为 true，设置密码后为 false
    /// - 找回密码：OTP验证后为 true，设置新密码后为 false
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    /// 当前认证流程类型
    @Published var currentFlowType: AuthFlowType = .none

    // MARK: - 私有属性

    /// 当前流程使用的邮箱（用于验证码验证）
    private var currentEmail: String?

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    /// 应用状态观察者
    private var appStateObservers: [NSObjectProtocol] = []

    // MARK: - 初始化

    private init() {
        // 启动认证状态监听
        startAuthStateListener()
        // 启动应用状态监听
        setupAppStateObservers()
    }

    deinit {
        authStateTask?.cancel()
        // 移除应用状态观察者
        appStateObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - 应用状态监听

    /// 设置应用状态观察者
    /// 当应用从后台回到前台时检查会话有效性
    private func setupAppStateObservers() {
        #if os(iOS)
        // 应用进入前台时检查会话
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.checkSessionOnForeground()
            }
        }
        appStateObservers.append(foregroundObserver)
        #endif
    }

    /// 应用进入前台时检查会话
    private func checkSessionOnForeground() async {
        // 只有在已认证状态下才检查
        guard isAuthenticated else { return }

        print("📱 应用进入前台，检查会话有效性...")

        let isValid = await validateSession()
        if !isValid {
            print("⚠️ 会话已失效，已跳转至登录页")
        }
    }

    // MARK: - 认证状态监听

    /// 启动认证状态变化监听
    /// 监听 Supabase 的 authStateChanges，自动响应登录/登出事件
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self = self else { return }

                await MainActor.run {
                    print("🔐 认证状态变化: \(event)")

                    switch event {
                    case .initialSession:
                        // 初始会话检查
                        if let session = session {
                            self.currentUser = session.user
                            // 只有在不需要设置密码时才设为已认证
                            if !self.needsPasswordSetup {
                                self.isAuthenticated = true
                            }
                            print("✅ 检测到初始会话: \(session.user.email ?? "unknown")")
                        } else {
                            self.currentUser = nil
                            self.isAuthenticated = false
                            print("ℹ️ 无初始会话")
                        }

                    case .signedIn:
                        // 登录成功
                        if let session = session {
                            self.currentUser = session.user
                            // 注意：如果是 OTP 验证后的登录，needsPasswordSetup 可能为 true
                            // 此时不应设置 isAuthenticated = true
                            if !self.needsPasswordSetup && !self.otpVerified {
                                self.isAuthenticated = true
                            }
                            print("✅ 用户登录: \(session.user.email ?? "unknown")")
                        }

                    case .signedOut:
                        // 登出
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.resetFlowState()
                        print("✅ 用户已登出")

                    case .tokenRefreshed:
                        // Token 刷新成功
                        if let session = session {
                            self.currentUser = session.user
                            self.isAuthenticated = true
                            print("🔄 Token 已刷新")
                        } else {
                            // Token 刷新但没有会话，可能出现问题
                            print("⚠️ Token 刷新但无会话")
                        }

                    case .userUpdated:
                        // 用户信息更新
                        if let session = session {
                            self.currentUser = session.user
                            print("🔄 用户信息已更新")
                        }

                    case .passwordRecovery:
                        // 密码恢复流程
                        print("🔑 密码恢复流程")

                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - ========== 注册流程 ==========

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    ///
    /// 调用 Supabase 的 `signInWithOTP`，成功后 `otpSent = true`
    func sendRegisterOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlowType = .register
        currentEmail = email

        do {
            // 使用 OTP 方式注册，shouldCreateUser: true 表示如果用户不存在则创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("📧 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// 调用 Supabase 的 `verifyOTP`，成功后：
    /// - `otpVerified = true`
    /// - `needsPasswordSetup = true`
    /// - 用户已登录，但 `isAuthenticated` 保持 `false`（需要设置密码）
    func verifyRegisterOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 使用 .email
            // verifyOTP 返回 AuthResponse，包含 session 和 user
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            // 从 session 中获取 user
            currentUser = response.session?.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，必须设置密码后才能进入主页

            print("✅ 注册验证码验证成功，等待设置密码")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    ///
    /// 调用 Supabase 的 `update(user:)` 设置密码，成功后：
    /// - `needsPasswordSetup = false`
    /// - `isAuthenticated = true`
    func completeRegistration(password: String) async {
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "密码长度至少6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            // update(user:) 直接返回 User 对象
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true
            otpSent = false
            otpVerified = false
            currentFlowType = .none

            print("✅ 注册完成，密码设置成功")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - ========== 登录流程 ==========

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    ///
    /// 调用 Supabase 的 `signIn(email:password:)`，成功后直接 `isAuthenticated = true`
    func signIn(email: String, password: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = response.user
            isAuthenticated = true

            // 重置所有流程状态
            resetFlowState()

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - ========== 找回密码流程 ==========

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    ///
    /// 调用 Supabase 的 `resetPasswordForEmail`，触发 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlowType = .resetPassword
        currentEmail = email

        do {
            // 发送重置密码邮件
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("📧 重置密码验证码已发送至: \(email)")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 发送重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    ///
    /// ⚠️ 注意：type 是 `.recovery` 不是 `.email`
    ///
    /// 调用 Supabase 的 `verifyOTP`，成功后：
    /// - `otpVerified = true`
    /// - `needsPasswordSetup = true`
    func verifyResetOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // ⚠️ 重要：找回密码使用 .recovery 类型
            // verifyOTP 返回 AuthResponse，包含 session 和 user
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // 注意：这里是 .recovery，不是 .email
            )

            // 从 session 中获取 user
            currentUser = response.session?.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置密码验证码验证成功，等待设置新密码")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 验证重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    ///
    /// 调用 Supabase 的 `update(user:)` 设置新密码，成功后：
    /// - `needsPasswordSetup = false`
    /// - `isAuthenticated = true`
    func resetPassword(newPassword: String) async {
        guard !newPassword.isEmpty else {
            errorMessage = "请输入新密码"
            return
        }

        guard newPassword.count >= 6 else {
            errorMessage = "密码长度至少6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            // update(user:) 直接返回 User 对象
            let user = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true

            // 重置流程状态
            resetFlowState()

            print("✅ 密码重置成功")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - ========== 第三方登录（预留） ==========

    /// Apple 登录
    /// - TODO: 实现 Sign in with Apple
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 获取 Apple ID credential
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 设置 isAuthenticated = true

        errorMessage = "Apple 登录功能开发中..."
        print("⚠️ Apple 登录功能尚未实现")
    }

    /// Google 登录
    /// - TODO: 实现 Sign in with Google
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        // 1. 使用 GoogleSignIn SDK 获取 ID token
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        // 3. 设置 isAuthenticated = true

        errorMessage = "Google 登录功能开发中..."
        print("⚠️ Google 登录功能尚未实现")
    }

    // MARK: - ========== 其他方法 ==========

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            currentUser = nil
            isAuthenticated = false
            resetFlowState()

            print("✅ 已退出登录")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查现有会话
    /// 应用启动时调用，检查是否有有效的登录会话
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查会话是否过期
            if isSessionExpired(session) {
                // 尝试刷新会话
                await refreshSession()
            } else {
                // 会话有效
                isAuthenticated = true
                print("✅ 检测到有效会话: \(session.user.email ?? "unknown")")
            }

        } catch {
            // 没有有效会话，保持未认证状态
            currentUser = nil
            isAuthenticated = false
            print("ℹ️ 无有效会话")
        }

        isLoading = false
    }

    /// 刷新会话
    /// 当会话即将过期或已过期时调用
    func refreshSession() async {
        do {
            let session = try await supabase.auth.refreshSession()
            currentUser = session.user
            isAuthenticated = true
            print("🔄 会话刷新成功")
        } catch {
            // 刷新失败，需要重新登录
            print("❌ 会话刷新失败: \(error)")
            await handleSessionExpired()
        }
    }

    /// 检查会话是否过期
    /// - Parameter session: 当前会话
    /// - Returns: 是否已过期或即将过期（提前5分钟）
    private func isSessionExpired(_ session: Session) -> Bool {
        let expiresAt = session.expiresAt ?? 0
        let expirationDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
        let bufferTime: TimeInterval = 5 * 60 // 5分钟缓冲
        return Date().addingTimeInterval(bufferTime) >= expirationDate
    }

    /// 处理会话过期
    /// 重置所有状态，触发 UI 跳转到登录页
    func handleSessionExpired() async {
        print("⚠️ 会话已过期，需要重新登录")

        // 尝试优雅地登出
        do {
            try await supabase.auth.signOut()
        } catch {
            print("⚠️ 登出时发生错误: \(error)")
        }

        // 重置所有状态
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
            resetFlowState()
            errorMessage = "登录已过期，请重新登录"
        }
    }

    /// 验证当前会话有效性
    /// 可在执行重要操作前调用，确保会话有效
    /// - Returns: 会话是否有效
    @discardableResult
    func validateSession() async -> Bool {
        do {
            let session = try await supabase.auth.session

            if isSessionExpired(session) {
                // 尝试刷新
                await refreshSession()
                // 再次检查
                let newSession = try await supabase.auth.session
                return !isSessionExpired(newSession)
            }

            return true
        } catch {
            // 无有效会话
            await handleSessionExpired()
            return false
        }
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置流程状态（用于取消当前流程或切换流程）
    func resetFlowState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        currentFlowType = .none
        currentEmail = nil
        errorMessage = nil
    }

    // MARK: - ========== 私有方法 ==========

    /// 处理认证错误，返回用户友好的错误信息
    /// - Parameter error: 原始错误
    /// - Returns: 用户友好的错误信息
    private func handleAuthError(_ error: Error) -> String {
        let errorString = String(describing: error).lowercased()

        // 网络错误
        if errorString.contains("network") ||
           errorString.contains("internet") ||
           errorString.contains("offline") ||
           errorString.contains("nsurlErrorDomain") {
            return "网络连接失败，请检查网络设置"
        }

        // 邮箱相关错误
        if errorString.contains("invalid email") ||
           errorString.contains("email not valid") {
            return "邮箱格式不正确"
        }

        if errorString.contains("email not confirmed") {
            return "邮箱尚未验证"
        }

        if errorString.contains("user already registered") ||
           errorString.contains("email already") {
            return "该邮箱已被注册"
        }

        // 密码相关错误
        if errorString.contains("invalid login credentials") ||
           errorString.contains("invalid password") ||
           errorString.contains("wrong password") {
            return "邮箱或密码错误"
        }

        if errorString.contains("password") && errorString.contains("weak") {
            return "密码强度不够，请使用更复杂的密码"
        }

        // 验证码相关错误
        if errorString.contains("otp") && errorString.contains("expired") {
            return "验证码已过期，请重新获取"
        }

        if errorString.contains("otp") && errorString.contains("invalid") ||
           errorString.contains("token") && errorString.contains("invalid") {
            return "验证码错误"
        }

        // 用户不存在
        if errorString.contains("user not found") ||
           errorString.contains("no user") {
            return "用户不存在"
        }

        // 请求频率限制
        if errorString.contains("rate limit") ||
           errorString.contains("too many requests") {
            return "请求过于频繁，请稍后再试"
        }

        // 会话相关
        if errorString.contains("session") && errorString.contains("expired") {
            return "登录已过期，请重新登录"
        }

        // 默认错误信息
        print("⚠️ 未处理的认证错误: \(error)")
        return "操作失败，请稍后重试"
    }
}

// MARK: - 便捷扩展
extension AuthManager {

    /// 当前流程使用的邮箱
    var flowEmail: String? {
        return currentEmail
    }

    /// 是否正在注册流程中
    var isInRegisterFlow: Bool {
        return currentFlowType == .register
    }

    /// 是否正在找回密码流程中
    var isInResetPasswordFlow: Bool {
        return currentFlowType == .resetPassword
    }

    /// 当前用户ID
    var userId: UUID? {
        return currentUser?.id
    }

    /// 当前用户邮箱
    var userEmail: String? {
        return currentUser?.email
    }
}
