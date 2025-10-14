//
//  LiquidGlassTabBar.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

// 底部导航栏项目枚举
enum TabItem: Int, CaseIterable {
    case home = 0
    case tools = 1
    case profile = 2
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .profile: return "person.fill"
        }
    }
    
    var title: String {
        switch self {
        case .home: return "主页"
        case .tools: return "工具"
        case .profile: return "我的"
        }
    }
    
    var color: Color {
        switch self {
        case .home: return .blue
        case .tools: return .purple
        case .profile: return .pink
        }
    }
}

// Liquid Glass效果的底部导航栏
struct LiquidGlassTabBar: View {
    @Binding var selectedTab: TabItem
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .frame(height: 70)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .background(
            // Liquid Glass 背景效果
            ZStack {
                // 主背景 - 毛玻璃效果
                RoundedRectangle(cornerRadius: 35)
                    .fill(.ultraThinMaterial)
                
                // 渐变光泽层
                RoundedRectangle(cornerRadius: 35)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 边框光晕
                RoundedRectangle(cornerRadius: 35)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // 内部高光
                RoundedRectangle(cornerRadius: 35)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.clear,
                                Color.black.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .padding(1)
            }
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        )
    }
}

// 单个标签按钮
struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            // 触觉反馈
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            VStack(spacing: 2) {
                ZStack {
                    // 图标
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 24 : 22, weight: .medium))
                        .foregroundStyle(
                            isSelected
                            ? LinearGradient(
                                colors: [tab.color, tab.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                }
                
                // 标签文字
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? tab.color : Color.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            LiquidGlassTabBar(selectedTab: .constant(.home))
        }
    }
}

