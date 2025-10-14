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
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.95, blue: 1.0),
                    Color(red: 1.0, green: 0.95, blue: 0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 用户信息卡片
                    VStack(spacing: 16) {
                        // 头像
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.6),
                                            Color.blue.opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 4) {
                            Text("用户名称")
                                .font(.system(size: 24, weight: .bold))
                            
                            Text("explorer@lovpic.com")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        // 统计信息
                        HStack(spacing: 32) {
                            StatItem(number: "128", label: "作品")
                            StatItem(number: "1.2K", label: "喜欢")
                            StatItem(number: "256", label: "收藏")
                        }
                        .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 功能菜单
                    VStack(spacing: 0) {
                        ProfileMenuItem(icon: "photo.on.rectangle", title: "我的作品", color: .blue)
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "heart.fill", title: "我的喜欢", color: .pink)
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "bookmark.fill", title: "我的收藏", color: .orange)
                        Divider().padding(.leading, 60)
                        ProfileMenuItem(icon: "gearshape.fill", title: "设置", color: .gray)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // 为底部导航留出空间
                }
            }
        }
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

