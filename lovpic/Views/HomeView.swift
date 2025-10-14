//
//  HomeView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.85, blue: 1.0),
                    Color(red: 0.85, green: 0.95, blue: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    Text("主页")
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    // 精选内容卡片
                    VStack(spacing: 16) {
                        ForEach(0..<5) { index in
                            GlassCard(
                                title: "精选图片 \(index + 1)",
                                subtitle: "探索美丽瞬间",
                                icon: "photo.on.rectangle.angled"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // 为底部导航留出空间
                }
            }
        }
    }
}

// 玻璃风格卡片组件
struct GlassCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            // 文字信息
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

#Preview {
    HomeView()
}

