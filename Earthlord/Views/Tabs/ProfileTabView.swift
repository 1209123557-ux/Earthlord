//
//  ProfileTabView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/8.
//

import SwiftUI
import Supabase

/// 个人页面：显示用户信息 + 退出登录
struct ProfileTabView: View {
    @ObservedObject private var authManager = AuthManager.shared

    /// 是否显示退出确认弹窗
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - 用户信息卡片
                        userInfoCard
                            .padding(.top, 20)

                        // MARK: - 数据统计
                        statsCard

                        // MARK: - 功能列表（预留）
                        menuSection

                        // MARK: - 退出登录按钮
                        logoutButton
                            .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("幸存者档案")
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出登录", role: .destructive) {
                    Task { await authManager.signOut() }
                }
            } message: {
                Text("退出后需要重新登录")
            }
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Text(avatarText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 用户名 / 邮箱 / ID
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(userEmail)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("ID: \(userId)")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.bottom, 8)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 数据统计卡片

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(icon: "flag.fill", value: "0", label: "领地")
            statDivider
            statItem(icon: "mappin.and.ellipse", value: "0", label: "资源点")
            statDivider
            statItem(icon: "figure.walk", value: "0", label: "探索距离")
        }
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(ApocalypseTheme.primary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 50)
    }

    // MARK: - 功能菜单（预留）

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "gearshape.fill", title: "设置", color: ApocalypseTheme.textSecondary)
            Divider().background(Color.white.opacity(0.06))
            menuRow(icon: "bell.fill", title: "通知", color: ApocalypseTheme.primary)
            Divider().background(Color.white.opacity(0.06))
            menuRow(icon: "questionmark.circle.fill", title: "帮助", color: ApocalypseTheme.info)
            Divider().background(Color.white.opacity(0.06))
            menuRow(icon: "info.circle.fill", title: "关于", color: ApocalypseTheme.success)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func menuRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(ApocalypseTheme.textMuted)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15))
                Text("退出登录")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.danger.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - 计算属性

    /// 头像文字（取邮箱首字母大写）
    private var avatarText: String {
        guard let email = authManager.currentUser?.email, !email.isEmpty else {
            return "?"
        }
        return String(email.prefix(1)).uppercased()
    }

    /// 显示名称
    private var displayName: String {
        // 优先取邮箱 @ 前面的部分作为用户名
        guard let email = authManager.currentUser?.email else {
            return "未知用户"
        }
        return String(email.split(separator: "@").first ?? "未知用户")
    }

    /// 用户邮箱
    private var userEmail: String {
        authManager.currentUser?.email ?? "未绑定邮箱"
    }

    /// 用户ID（截取前8位 + ...）
    private var userId: String {
        let id = authManager.currentUser?.id.uuidString ?? "未知"
        if id.count > 8 {
            return String(id.prefix(8)) + "..."
        }
        return id
    }
}

#Preview {
    ProfileTabView()
}
