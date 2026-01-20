//
//  ProfileView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @State private var showAuthView = false
    @State private var showLogoutAlert = false
    
    private var authManager: AuthManager { AuthManager.shared }
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.98, green: 0.98, blue: 0.99)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 用户信息卡片
                    if authManager.isLoggedIn {
                        LoggedInUserCard(
                            profile: authManager.userProfile,
                            email: authManager.currentUser?.email,
                            onLogout: { showLogoutAlert = true }
                        )
                    } else {
                        GuestUserCard(onLogin: { showAuthView = true })
                    }
                    
                    // 常用工具
                    CommonToolsSection()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // 为底部导航留出空间
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showAuthView) {
            AuthView()
        }
        .alert("退出登录", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
    }
}

// 已登录用户卡片
struct LoggedInUserCard: View {
    let profile: UserProfile?
    let email: String?
    let onLogout: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.7, blue: 0.4),
                                Color(red: 1.0, green: 0.5, blue: 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                if let avatarUrl = profile?.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 6) {
                Text(profile?.displayName ?? email ?? "用户")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(profile?.membershipDisplayName ?? "普通会员")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 退出按钮
            Button(action: onLogout) {
                Text("退出")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// 未登录用户卡片
struct GuestUserCard: View {
    let onLogin: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }
            
            // 提示信息
            VStack(alignment: .leading, spacing: 6) {
                Text("未登录")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("登录后享受更多功能")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 登录按钮
            Button(action: onLogin) {
                Text("登录/注册")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.7, blue: 0.4),
                                Color(red: 1.0, green: 0.5, blue: 0.5)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// 统计卡片
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let iconBackground: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// 常用工具区域
struct CommonToolsSection: View {
    let tools = [
        ToolItemData(icon: "message", label: "联系客服", color: Color(red: 1.0, green: 0.5, blue: 0.5)),
        ToolItemData(icon: "doc.text", label: "服务条款", color: Color(red: 0.5, green: 0.7, blue: 1.0)),
        ToolItemData(icon: "info.circle", label: "关于我们", color: Color(red: 0.6, green: 0.8, blue: 0.5))
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用工具")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            // 3个工具项
            VStack(spacing: 12) {
                ForEach(tools) { tool in
                    CommonToolItem(tool: tool)
                }
            }
        }
    }
}

// 工具项数据
struct ToolItemData: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
}

// 常用工具项
struct CommonToolItem: View {
    let tool: ToolItemData
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.system(size: 22))
                    .foregroundColor(tool.color)
                    .frame(width: 28)
                
                Text(tool.label)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 统计项组件
struct StatItem: View {
    let number: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

// 个人中心菜单项
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
