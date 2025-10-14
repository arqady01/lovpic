//
//  MainTabView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    
    var body: some View {
        ZStack {
            // 主内容区域
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case .tools:
                    ToolsView()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                case .profile:
                    ProfileView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            
            // Liquid Glass底部导航栏
            VStack {
                Spacer()
                LiquidGlassTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    MainTabView()
}

