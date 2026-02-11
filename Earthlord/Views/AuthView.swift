//
//  AuthView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/11.
//

import SwiftUI

/// 认证页面：登录 / 注册 / 找回密码
struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的Tab：0=登录，1=注册
    @State private var selectedTab = 0

    /// 是否显示找回密码弹窗
    @State private var showResetPassword = false

    /// 第三方登录提示
    @State private var showComingSoon = false

    var body: some View {
        ZStack {
            // MARK: - 背景渐变
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // MARK: - 顶部 Logo
                    logoSection
                        .padding(.top, 50)

                    // MARK: - Tab 切换
                    tabPicker

                    // MARK: - 错误提示
                    if let error = authManager.errorMessage {
                        errorBanner(error)
                    }

                    // MARK: - 内容区域
                    if selectedTab == 0 {
                        loginSection
                    } else {
                        registerSection
                    }

                    // MARK: - 分隔线
                    dividerSection

                    // MARK: - 第三方登录
                    thirdPartySection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }

            // MARK: - 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // MARK: - "即将开放" Toast
            if showComingSoon {
                comingSoonToast
            }
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordSheet(authManager: authManager)
        }
    }

    // MARK: - Logo 区域

    private var logoSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 15)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            Text("地球新主")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("EARTH LORD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(3)
        }
    }

    // MARK: - Tab 切换器

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                // 切换Tab时清除错误
                authManager.errorMessage = nil
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(selectedTab == index ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedTab == index
                        ? ApocalypseTheme.primary
                        : Color.clear
                )
                .cornerRadius(12)
        }
    }

    // MARK: - 错误横幅

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.danger)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.danger)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ApocalypseTheme.danger.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - 登录区域

    private var loginSection: some View {
        LoginSection(authManager: authManager, showResetPassword: $showResetPassword)
    }

    // MARK: - 注册区域

    private var registerSection: some View {
        RegisterSection(authManager: authManager)
    }

    // MARK: - 分隔线

    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 0.5)
            Text("或者使用以下方式登录")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .fixedSize()
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 0.5)
        }
    }

    // MARK: - 第三方登录

    private var thirdPartySection: some View {
        VStack(spacing: 12) {
            // Apple 登录按钮
            Button {
                showComingSoonToast()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18))
                    Text("通过 Apple 登录")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }

            // Google 登录按钮
            Button {
                showComingSoonToast()
            } label: {
                HStack(spacing: 8) {
                    Text("G")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                    Text("通过 Google 登录")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)
        }
    }

    // MARK: - "即将开放" Toast

    private var comingSoonToast: some View {
        VStack {
            Spacer()
            Text("即将开放，敬请期待")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground.opacity(0.95))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 10)
                .padding(.bottom, 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }

    private func showComingSoonToast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showComingSoon = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showComingSoon = false
            }
        }
    }
}

// MARK: - 登录区域组件

private struct LoginSection: View {
    @ObservedObject var authManager: AuthManager
    @Binding var showResetPassword: Bool

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入
            AuthSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $password
            )

            // 登录按钮
            PrimaryButton(title: "登录") {
                await authManager.signIn(email: email, password: password)
            }
            .disabled(email.isEmpty || password.isEmpty)

            // 忘记密码
            Button {
                showResetPassword = true
            } label: {
                Text("忘记密码？")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }
}

// MARK: - 注册区域组件（三步流程）

private struct RegisterSection: View {
    @ObservedObject var authManager: AuthManager

    @State private var email = ""
    @State private var otpCode = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    /// 重发倒计时
    @State private var countdown = 0
    @State private var countdownTimer: Timer?

    /// 当前步骤（根据 authManager 状态自动判断）
    private var currentStep: Int {
        if authManager.otpVerified && authManager.needsPasswordSetup {
            return 3 // 第三步：设置密码
        } else if authManager.otpSent {
            return 2 // 第二步：输入验证码
        } else {
            return 1 // 第一步：输入邮箱
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 步骤指示器
            stepIndicator

            switch currentStep {
            case 1:
                stepOneView
            case 2:
                stepTwoView
            case 3:
                stepThreeView
            default:
                EmptyView()
            }
        }
    }

    // MARK: - 步骤指示器

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 0) {
                    // 圆点
                    Circle()
                        .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    // 连接线（最后一个不显示）
                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - 第一步：输入邮箱

    private var stepOneView: some View {
        VStack(spacing: 16) {
            Text("输入邮箱注册")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                await authManager.sendRegisterOTP(email: email)
                if authManager.otpSent {
                    startCountdown()
                }
            }
            .disabled(email.isEmpty)
        }
    }

    // MARK: - 第二步：输入验证码

    private var stepTwoView: some View {
        VStack(spacing: 16) {
            Text("验证码已发送至 \(email)")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 6位验证码输入
            AuthTextField(
                icon: "number",
                placeholder: "请输入6位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )

            PrimaryButton(title: "验证") {
                await authManager.verifyRegisterOTP(email: email, code: otpCode)
            }
            .disabled(otpCode.count < 6)

            // 重发按钮（带倒计时）
            Button {
                Task {
                    await authManager.sendRegisterOTP(email: email)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            } label: {
                Text(countdown > 0 ? "重新发送（\(countdown)s）" : "重新发送验证码")
                    .font(.system(size: 14))
                    .foregroundColor(countdown > 0 ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            }
            .disabled(countdown > 0)
        }
    }

    // MARK: - 第三步：设置密码

    private var stepThreeView: some View {
        VStack(spacing: 16) {
            Text("验证成功！请设置登录密码")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.success)

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "设置密码（至少6位）",
                text: $password
            )

            AuthSecureField(
                icon: "lock.rotation",
                placeholder: "确认密码",
                text: $confirmPassword
            )

            // 密码不匹配提示
            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "完成注册") {
                await authManager.completeRegistration(password: password)
            }
            .disabled(password.count < 6 || password != confirmPassword)
        }
    }

    // MARK: - 倒计时

    private func startCountdown() {
        countdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
        }
    }
}

// MARK: - 找回密码弹窗

private struct ResetPasswordSheet: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var countdown = 0
    @State private var countdownTimer: Timer?

    /// 弹窗内部步骤
    @State private var step = 1

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 步骤指示
                    Text("找回密码 - 第\(step)步/共3步")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.top, 8)

                    // 错误提示
                    if let error = authManager.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 13))
                                .lineLimit(2)
                        }
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ApocalypseTheme.danger.opacity(0.1))
                        .cornerRadius(10)
                    }

                    switch step {
                    case 1:
                        resetStepOne
                    case 2:
                        resetStepTwo
                    case 3:
                        resetStepThree
                    default:
                        EmptyView()
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)

                // 加载遮罩
                if authManager.isLoading {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView().scaleEffect(1.5).tint(ApocalypseTheme.primary)
                    }
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 第一步：输入邮箱

    private var resetStepOne: some View {
        VStack(spacing: 16) {
            Text("输入注册时使用的邮箱")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                await authManager.sendResetOTP(email: email)
                if authManager.otpSent {
                    step = 2
                    startCountdown()
                }
            }
            .disabled(email.isEmpty)
        }
    }

    // MARK: - 第二步：输入验证码

    private var resetStepTwo: some View {
        VStack(spacing: 16) {
            Text("验证码已发送至 \(email)")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            AuthTextField(
                icon: "number",
                placeholder: "请输入6位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )

            PrimaryButton(title: "验证") {
                await authManager.verifyResetOTP(email: email, code: otpCode)
                if authManager.otpVerified {
                    step = 3
                }
            }
            .disabled(otpCode.count < 6)

            Button {
                Task {
                    await authManager.sendResetOTP(email: email)
                    startCountdown()
                }
            } label: {
                Text(countdown > 0 ? "重新发送（\(countdown)s）" : "重新发送验证码")
                    .font(.system(size: 14))
                    .foregroundColor(countdown > 0 ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            }
            .disabled(countdown > 0)
        }
    }

    // MARK: - 第三步：设置新密码

    private var resetStepThree: some View {
        VStack(spacing: 16) {
            Text("请设置新密码")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $newPassword
            )

            AuthSecureField(
                icon: "lock.rotation",
                placeholder: "确认新密码",
                text: $confirmPassword
            )

            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            PrimaryButton(title: "重置密码") {
                await authManager.resetPassword(newPassword: newPassword)
                if authManager.isAuthenticated {
                    dismiss()
                }
            }
            .disabled(newPassword.count < 6 || newPassword != confirmPassword)
        }
    }

    private func startCountdown() {
        countdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
        }
    }
}

// MARK: - 通用输入框组件

/// 带图标的文本输入框
private struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(ApocalypseTheme.textMuted))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

/// 带图标的密码输入框（支持显示/隐藏）
private struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            if isVisible {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(ApocalypseTheme.textMuted))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(ApocalypseTheme.textMuted))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .textInputAutocapitalization(.never)
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

/// 主题色主按钮
private struct PrimaryButton: View {
    let title: String
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
        }
    }
}

// MARK: - 预览

#Preview {
    AuthView()
}
