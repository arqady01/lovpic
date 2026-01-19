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
    
    var gradientColors: [Color] {
        switch self {
        case .home: return [Color(hex: "4F46E5"), Color(hex: "818CF8")]
        case .tools: return [Color(hex: "8B5CF6"), Color(hex: "A78BFA")]
        case .profile: return [Color(hex: "EC4899"), Color(hex: "F472B6")]
        }
    }
}

// Liquid Glass效果的底部导航栏
struct LiquidGlassTabBar: View {
    @Binding var selectedTab: TabItem
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .frame(height: 75)
        .padding(.horizontal, 16)
        .background(
            LiquidGlassBackground(colorScheme: colorScheme)
                .padding(.horizontal, 16)
        )
        .padding(.bottom, 24)
    }
}

// MARK: - Liquid Glass Background
struct LiquidGlassBackground: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            // 主背景 - 毛玻璃效果
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
            
            // 虹彩渐变层 (Liquid Glass 特色)
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "818CF8").opacity(0.08),
                            Color(hex: "EC4899").opacity(0.05),
                            Color(hex: "4F46E5").opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 顶部高光
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            
            // 边框 - 双层效果
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.3 : 0.7),
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // 选中状态背景指示器
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: tab.gradientColors.map { $0.opacity(0.15) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .matchedGeometryEffect(id: "selectedBackground", in: namespace)
                    }
                    
                    // 图标
                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            isSelected
                            ? LinearGradient(
                                colors: tab.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(hex: "64748B"), Color(hex: "64748B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce.byLayer, value: isSelected)
                }
                .frame(height: 44)
                
                // 标签文字
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                        ? LinearGradient(
                            colors: tab.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color(hex: "64748B"), Color(hex: "64748B")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "F8FAFC"), Color(hex: "EEF2FF")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            LiquidGlassTabBar(selectedTab: .constant(.home))
        }
    }
}

#Preview("Dark Mode") {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            LiquidGlassTabBar(selectedTab: .constant(.tools))
        }
    }
    .preferredColorScheme(.dark)
}
