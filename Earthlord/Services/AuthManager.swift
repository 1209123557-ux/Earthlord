//
//  AuthManager.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/11.
//

import Foundation
import Combine
import Supabase

/// 认证管理器
/// 管理用户的注册、登录、找回密码等认证流程
///
/// 认证模式：
/// - 注册：发验证码 → 验证（此时已登录但没密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证（此时已登录）→ 设置新密码 → 完成
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有流程，包括密码设置）
    @Published var isAuthenticated: Bool = false

    /// OTP验证后是否需要设置密码（注册/找回密码流程中间态）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 验证码是否已发送
    @Published var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 单例

    static let shared = AuthManager()

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    private init() {
        startAuthStateListener()
    }

    // MARK: - 认证状态监听

    /// 监听 Supabase 认证状态变化，自动切换登录/登出
    private func startAuthStateListener() {
        authStateTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self = self else { break }

                switch event {
                case .signedIn:
                    // 用户登录（密码登录、OTP验证等都会触发）
                    self.currentUser = session?.user
                    // 如果正在注册流程中（需要设置密码），不自动标记为已认证
                    if !self.needsPasswordSetup {
                        self.isAuthenticated = true
                    }

                case .signedOut:
                    // 用户登出（手动登出、token 过期等）
                    self.resetState()

                case .tokenRefreshed:
                    // Token 刷新成功，更新用户信息
                    self.currentUser = session?.user

                case .userUpdated:
                    // 用户信息更新（设置密码等）
                    self.currentUser = session?.user

                default:
                    break
                }
            }
        }
    }

    // MARK: - 注册流程

    /// 注册第一步：发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // shouldCreateUser: true 表示如果用户不存在则自动创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )
            otpSent = true
        } catch {
            errorMessage = "发送验证码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 注册第二步：验证注册验证码
    /// ⚠️ 验证成功后用户已登录，但 isAuthenticated 保持 false，必须设置密码才能进入主页
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        // ⚠️ 必须在 verifyOTP 之前设置，防止竞态条件：
        // verifyOTP 会立即触发 Supabase .signedIn 事件，
        // 若此时 needsPasswordSetup=false，监听器会直接把 isAuthenticated 设为 true，跳过密码设置步骤。
        needsPasswordSetup = true

        do {
            // type: .email 用于注册/登录验证
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )
            currentUser = response.user
            otpVerified = true
            // isAuthenticated 保持 false，强制用户完成第三步（设置密码）
        } catch {
            needsPasswordSetup = false  // 验证失败，重置状态
            errorMessage = "验证码验证失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 注册第三步：设置密码完成注册
    /// - Parameter password: 用户设置的密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 用户已登录（OTP验证后），直接更新密码
            // auth.update 直接返回 User 类型
            currentUser = try await supabase.auth.update(user: UserAttributes(password: password))

            // 密码设置完成，认证流程结束
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true
        } catch {
            errorMessage = "设置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 邮箱密码登录（直接登录，无需额外步骤）
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 找回密码第一步：发送重置验证码
    /// 这会触发 Supabase 的 Reset Password 邮件模板
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            otpSent = true
        } catch {
            errorMessage = "发送重置验证码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 找回密码第二步：验证重置验证码
    /// ⚠️ 注意：type 是 .recovery 而不是 .email
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // type: .recovery 用于密码重置验证
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )
            currentUser = response.user

            // 验证成功，进入新密码设置阶段
            otpVerified = true
            needsPasswordSetup = true
        } catch {
            errorMessage = "重置验证码验证失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 找回密码第三步：设置新密码
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 用户已登录（OTP验证后），更新密码
            // auth.update 直接返回 User 类型
            currentUser = try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 密码重置完成
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true
        } catch {
            errorMessage = "重置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 集成 Sign in with Apple，需要配置 Apple Developer 证书和 Supabase OAuth
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
    }

    /// Google 登录
    /// TODO: 集成 Google Sign-In SDK，需要配置 Google Cloud Console 和 Supabase OAuth
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
    }

    // MARK: - 其他方法

    /// 退出登录，重置所有状态
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = "退出登录失败：\(error.localizedDescription)"
        }

        // 无论成功失败，都重置本地状态
        resetState()
        isLoading = false
    }

    /// 删除账户：调用 delete-account 边缘函数
    func deleteAccount() async {
        print("[删除账户] 开始删除账户流程")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前会话的 access token
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            print("[删除账户] 已获取用户 access token")

            // 调用 delete-account 边缘函数
            // SDK 不会自动带 Authorization，需要手动传入
            print("[删除账户] 正在调用 delete-account 边缘函数...")
            try await supabase.functions.invoke(
                "delete-account",
                options: .init(
                    headers: ["Authorization": "Bearer \(accessToken)"]
                )
            )

            print("[删除账户] 服务端删除成功，正在清除本地会话...")
            // 清除本地 session，触发 auth 状态监听 → 回到登录页
            try? await supabase.auth.signOut()
            resetState()
        } catch FunctionsError.httpError(let code, let data) {
            let body = String(data: data, encoding: .utf8) ?? "无法解析"
            print("[删除账户] 边缘函数返回错误，状态码: \(code)，响应: \(body)")
            errorMessage = "删除账户失败，请稍后重试"
        } catch {
            print("[删除账户] 发生错误: \(error.localizedDescription)")
            errorMessage = "删除账户失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 检查现有会话，用于应用启动时恢复登录状态
    func checkSession() async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否有密码（通过 identities 判断）
            // 如果用户只有 email identity 且没有设置过密码，需要补设密码
            // 正常登录过的用户直接标记为已认证
            isAuthenticated = true
        } catch {
            // 没有有效会话，用户未登录
            resetState()
        }

        isLoading = false
    }

    // MARK: - 私有方法

    /// 重置所有认证状态
    private func resetState() {
        isAuthenticated = false
        needsPasswordSetup = false
        currentUser = nil
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }
}
