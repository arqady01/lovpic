//
//  ProfileView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.98, green: 0.98, blue: 0.99)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 用户信息卡片
                    UserInfoCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    
                    // AI使用统计卡片（横向2个）
                    HStack(spacing: 12) {
                        StatCard(
                            icon: "wand.and.stars",
                            iconColor: Color(red: 1.0, green: 0.4, blue: 0.4),
                            value: "128",
                            label: "AI编辑次数",
                            iconBackground: Color(red: 1.0, green: 0.93, blue: 0.93)
                        )
                        
                        StatCard(
                            icon: "folder.fill",
                            iconColor: Color(red: 0.4, green: 0.6, blue: 1.0),
                            value: "2.5GB",
                            label: "存储空间",
                            iconBackground: Color(red: 0.93, green: 0.95, blue: 1.0)
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 我的作品区域
                    MyWorksSection()
                        .padding(.horizontal, 16)
                    
                    // 签到卡片
                    VIPCard()
                        .padding(.horizontal, 16)
                    
                    // 常用工具
                    CommonToolsSection()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // 为底部导航留出空间
                }
            }
        }
    }
}

// 用户信息卡片
struct UserInfoCard: View {
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
                
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 6) {
                Text("185****9654")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("普通会员")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 编辑资料按钮
            Button(action: {}) {
                Text("编辑资料")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
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

// 会员中心区域
struct MyWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会员中心")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            // 会员功能网格（一行4个）
            HStack(spacing: 0) {
                VIPMenuItem(icon: "crown.fill", label: "会员权益")
                VIPMenuItem(icon: "list.bullet.rectangle", label: "套餐对比")
                VIPMenuItem(icon: "doc.text.fill", label: "订单记录")
                VIPMenuItem(icon: "questionmark.circle.fill", label: "常见问题")
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
}

// VIP菜单项
struct VIPMenuItem: View {
    let icon: String
    let label: String
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.5))
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// VIP升级卡片
struct VIPCard: View {
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                    
                    Text("升级VIP会员")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("解锁全部AI功能")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Button(action: {}) {
                Text("立即升级")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.4))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.3),
                            Color(red: 1.0, green: 0.45, blue: 0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.orange.opacity(0.3), radius: 12, x: 0, y: 6)
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

