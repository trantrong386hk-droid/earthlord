import SwiftUI
import Supabase

// MARK: - Supabase 客户端初始化
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://umbuyozeejvgjampncuq.supabase.co")!,
    supabaseKey: "sb_secret_VOrm2pKfD-edykgv_7QXfA_Oz64pJ9K"
)

// MARK: - 连接状态枚举
enum ConnectionStatus {
    case idle
    case testing
    case success
    case failure
}

// MARK: - Supabase 测试视图
struct SupabaseTestView: View {
    @State private var status: ConnectionStatus = .idle
    @State private var logText: String = "点击按钮开始测试连接..."

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 状态图标
                statusIcon
                    .frame(width: 80, height: 80)

                // 状态文字
                statusText

                // 日志显示区域
                ScrollView {
                    Text(logText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if status == .testing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "network")
                        }
                        Text(status == .testing ? "测试中..." : "测试连接")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        status == .testing
                            ? ApocalypseTheme.textMuted
                            : ApocalypseTheme.primary
                    )
                    .cornerRadius(12)
                }
                .disabled(status == .testing)

                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Supabase 测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
        case .testing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(2)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.success)
        case .failure:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.danger)
        }
    }

    // MARK: - 状态文字
    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .idle:
            Text("等待测试")
                .foregroundColor(ApocalypseTheme.textSecondary)
        case .testing:
            Text("正在连接...")
                .foregroundColor(ApocalypseTheme.primary)
        case .success:
            Text("连接成功")
                .foregroundColor(ApocalypseTheme.success)
                .fontWeight(.semibold)
        case .failure:
            Text("连接失败")
                .foregroundColor(ApocalypseTheme.danger)
                .fontWeight(.semibold)
        }
    }

    // MARK: - 测试连接
    private func testConnection() {
        status = .testing
        logText = "[\(timestamp)] 开始测试连接...\n"
        logText += "[\(timestamp)] URL: https://umbuyozeejvgjampncuq.supabase.co\n"
        logText += "[\(timestamp)] 尝试查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（不太可能），也算成功
                await MainActor.run {
                    status = .success
                    logText += "[\(timestamp)] ✅ 连接成功！查询返回正常\n"
                }

            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    // MARK: - 错误处理
    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        logText += "[\(timestamp)] 收到响应，分析中...\n"
        logText += "[\(timestamp)] 错误详情: \(errorString)\n"

        // 检查是否是 PostgreSQL REST API 错误（说明连接成功）
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("relation") && errorString.contains("does not exist") ||
           errorString.contains("table") && errorString.contains("not found") ||
           errorString.contains("42P01") {  // PostgreSQL 表不存在错误码

            status = .success
            logText += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            logText += "[\(timestamp)] 说明：查询的表不存在是预期行为，\n"
            logText += "[\(timestamp)] 这证明 Supabase 服务器正常工作！\n"

        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") ||
                  errorString.contains("Network") ||
                  errorString.contains("internet") {

            status = .failure
            logText += "[\(timestamp)] ❌ 连接失败：URL 错误或无网络\n"
            logText += "[\(timestamp)] 请检查：\n"
            logText += "[\(timestamp)]   1. 网络连接是否正常\n"
            logText += "[\(timestamp)]   2. Supabase URL 是否正确\n"

        } else if errorString.contains("Invalid API key") ||
                  errorString.contains("apikey") ||
                  errorString.contains("unauthorized") ||
                  errorString.contains("401") {

            status = .failure
            logText += "[\(timestamp)] ❌ 连接失败：API Key 无效\n"
            logText += "[\(timestamp)] 请检查 Supabase Key 是否正确\n"

        } else {
            // 其他未知错误
            status = .failure
            logText += "[\(timestamp)] ❌ 未知错误\n"
            logText += "[\(timestamp)] 错误类型: \(type(of: error))\n"
        }
    }

    // MARK: - 时间戳
    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 空响应模型
struct EmptyResponse: Codable {}

// MARK: - Preview
#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
