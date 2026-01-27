//
//  AuthView.swift
//  earthlord
//
//  EarthLord 认证页面
//  包含登录、注册、忘记密码功能
//

import SwiftUI

// MARK: - 认证页面
struct AuthView: View {

    // MARK: - 属性
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的Tab（0: 登录, 1: 注册）
    @State private var selectedTab: Int = 0

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword: Bool = false

    /// Toast 消息
    @State private var toastMessage: String?

    // MARK: - Body
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            // 主内容
            ScrollView {
                VStack(spacing: 32) {
                    // Logo 和标题
                    headerSection

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    contentSection

                    // 分隔线
                    dividerSection

                    // 第三方登录
                    socialLoginSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(authManager: authManager)
        }
        // 监听错误信息
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let error = newValue {
                showToast(error)
                authManager.clearError()
            }
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.08),
                Color(red: 0.10, green: 0.08, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.10)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 头部区域
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Logo
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

            // 标题
            Text("废墟圈地记")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text("EARTH LORD")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)
                .tracking(4)
        }
    }

    // MARK: - Tab 选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            TabButton(
                title: "登录",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                    authManager.resetFlowState()
                }
            }

            // 注册 Tab
            TabButton(
                title: "注册",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                    authManager.resetFlowState()
                }
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 内容区域
    @ViewBuilder
    private var contentSection: some View {
        if selectedTab == 0 {
            LoginSection(
                authManager: authManager,
                onForgotPassword: { showForgotPassword = true }
            )
        } else {
            RegisterSection(authManager: authManager)
        }
    }

    // MARK: - 分隔线
    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .fixedSize()

            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - 第三方登录
    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            // Apple 登录
            SocialLoginButton(
                icon: "apple.logo",
                title: "通过 Apple 登录",
                backgroundColor: .black,
                foregroundColor: .white
            ) {
                Task {
                    await authManager.signInWithApple()
                }
            }

            // Google 登录
            SocialLoginButton(
                icon: "g.circle.fill",
                title: "通过 Google 登录",
                backgroundColor: .white,
                foregroundColor: .black
            ) {
                Task {
                    await authManager.signInWithGoogle()
                }
            }
        }
    }

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(1.5)

                Text("处理中...")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 视图
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - 显示 Toast
    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Tab 按钮
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isSelected
                        ? ApocalypseTheme.primary.opacity(0.15)
                        : Color.clear
                )
        }
        .cornerRadius(12)
    }
}

// MARK: - ========== 登录区域 ==========
struct LoginSection: View {
    @ObservedObject var authManager: AuthManager
    let onForgotPassword: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // 邮箱输入框
            AuthTextField(
                icon: "envelope",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入框
            AuthTextField(
                icon: "lock",
                placeholder: "密码",
                text: $password,
                isSecure: true
            )

            // 登录按钮
            PrimaryButton(title: "登录") {
                Task {
                    await authManager.signIn(email: email, password: password)
                }
            }
            .disabled(email.isEmpty || password.isEmpty)

            // 忘记密码
            Button(action: onForgotPassword) {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }
}

// MARK: - ========== 注册区域 ==========
struct RegisterSection: View {
    @ObservedObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    /// 重发倒计时
    @State private var resendCountdown: Int = 0
    @State private var countdownTimer: Timer?

    /// 当前步骤（根据 authManager 状态自动计算）
    private var currentStep: Int {
        if authManager.otpSent {
            return 2  // 第二步：验证码
        } else {
            return 1  // 第一步：邮箱和密码
        }
    }

    /// 密码是否有效
    private var isPasswordValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 24) {
            // 步骤指示器
            StepIndicator(currentStep: currentStep, totalSteps: 2)

            // 根据步骤显示不同内容
            switch currentStep {
            case 1:
                step1EmailAndPassword
            case 2:
                step2OTPVerification
            default:
                EmptyView()
            }
        }
    }

    // MARK: - 第一步：邮箱和密码输入
    private var step1EmailAndPassword: some View {
        VStack(spacing: 20) {
            Text("创建您的账户")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            AuthTextField(
                icon: "envelope",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            AuthTextField(
                icon: "lock",
                placeholder: "密码（至少6位）",
                text: $password,
                isSecure: true
            )

            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $confirmPassword,
                isSecure: true
            )

            // 密码不匹配提示
            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendRegisterOTP(email: email, password: password)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
            .disabled(email.isEmpty || !isValidEmail(email) || !isPasswordValid)

            if !email.isEmpty && !isValidEmail(email) {
                Text("请输入有效的邮箱地址")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
    }

    // MARK: - 第二步：验证码验证
    private var step2OTPVerification: some View {
        VStack(spacing: 20) {
            Text("验证您的邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(email)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入
            OTPInputField(code: $otpCode)

            // 验证按钮
            PrimaryButton(title: "完成注册") {
                Task {
                    await authManager.verifyRegisterOTP(email: email, code: otpCode)
                }
            }
            .disabled(otpCode.count != 6)

            // 重发按钮
            HStack {
                Text("没有收到验证码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)

                if resendCountdown > 0 {
                    Text("\(resendCountdown)秒后重发")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button("重新发送") {
                        Task {
                            await authManager.sendRegisterOTP(email: email, password: password)
                            if authManager.otpSent {
                                startCountdown()
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    private func startCountdown() {
        resendCountdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - ========== 忘记密码弹窗 ==========
struct ForgotPasswordSheet: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var resendCountdown: Int = 0
    @State private var countdownTimer: Timer?

    /// 当前步骤
    private var currentStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified && authManager.currentFlowType == .resetPassword {
            return 3
        } else if authManager.otpSent && authManager.currentFlowType == .resetPassword {
            return 2
        } else {
            return 1
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 步骤指示器
                    StepIndicator(currentStep: currentStep, totalSteps: 3)

                    // 内容
                    switch currentStep {
                    case 1:
                        forgotStep1
                    case 2:
                        forgotStep2
                    case 3:
                        forgotStep3
                    default:
                        EmptyView()
                    }

                    Spacer()
                }
                .padding(24)

                // 加载遮罩
                if authManager.isLoading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        authManager.resetFlowState()
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        // 监听认证成功
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }

    // MARK: - 第一步：输入邮箱
    private var forgotStep1: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.primary)

            Text("输入您的注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("我们将发送验证码到您的邮箱")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "envelope",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: email)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
            .disabled(email.isEmpty)
        }
    }

    // MARK: - 第二步：验证码
    private var forgotStep2: some View {
        VStack(spacing: 20) {
            Image(systemName: "number.square")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.primary)

            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(email)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            OTPInputField(code: $otpCode)

            PrimaryButton(title: "验证") {
                Task {
                    await authManager.verifyResetOTP(email: email, code: otpCode)
                }
            }
            .disabled(otpCode.count != 6)

            // 重发
            HStack {
                if resendCountdown > 0 {
                    Text("\(resendCountdown)秒后可重发")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Button("重新发送验证码") {
                        Task {
                            await authManager.sendResetOTP(email: email)
                            if authManager.otpSent {
                                startCountdown()
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 第三步：新密码
    private var forgotStep3: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.success)

            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            AuthTextField(
                icon: "lock",
                placeholder: "新密码（至少6位）",
                text: $newPassword,
                isSecure: true
            )

            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $confirmPassword,
                isSecure: true
            )

            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "重置密码") {
                Task {
                    await authManager.resetPassword(newPassword: newPassword)
                }
            }
            .disabled(newPassword.count < 6 || newPassword != confirmPassword)
        }
    }

    private func startCountdown() {
        resendCountdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - ========== 通用组件 ==========

// MARK: - 输入框
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var isPasswordVisible: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 24)

            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 主按钮
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isEnabled
                        ? ApocalypseTheme.primary
                        : ApocalypseTheme.textMuted
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - 第三方登录按钮
struct SocialLoginButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(width: 10, height: 10)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - OTP 输入框
struct OTPInputField: View {
    @Binding var code: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.cardBackground)
                        .frame(width: 45, height: 55)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    index < code.count
                                        ? ApocalypseTheme.primary
                                        : ApocalypseTheme.textMuted.opacity(0.3),
                                    lineWidth: 1
                                )
                        )

                    if index < code.count {
                        let char = Array(code)[index]
                        Text(String(char))
                            .font(.title2.bold())
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }
        }
        .overlay(
            // 隐藏的输入框用于接收键盘输入
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .onChange(of: code) { _, newValue in
                    // 限制6位数字
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count <= 6 {
                        code = filtered
                    } else {
                        code = String(filtered.prefix(6))
                    }
                }
        )
    }
}

// MARK: - Preview
#Preview {
    AuthView()
}
