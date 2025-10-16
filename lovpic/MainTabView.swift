//
//  MainTabView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var homeDetailActive = false
    @State private var toolsDetailActive = false

    var body: some View {
        ZStack {
            // 主内容区域
            Group {
                switch selectedTab {
                case .home:
                    HomeView(isPresentingDetail: $homeDetailActive)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case .tools:
                    ToolsView(isPresentingDetail: $toolsDetailActive)
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
                    .opacity((homeDetailActive || toolsDetailActive) ? 0 : 1)
                    .allowsHitTesting(!(homeDetailActive || toolsDetailActive))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != .home {
                homeDetailActive = false
            }
            if newValue != .tools {
                toolsDetailActive = false
            }
        }
    }
}

#Preview {
    MainTabView()
}
