//
//  ToolsView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct ToolsView: View {
    private enum Destination: Hashable {
        case imageEnhancement
        case framedScreenshot
        case backgroundRemoval
        case imageStitching
        case realTimeRecognition
        case safeCode
    }
    
    private let tools = [
        ToolItem(
            icon: "eye.trianglebadge.exclamationmark",
            title: "画质增强",
            description: "算法提升画质",
            color: Color(red: 0.65, green: 0.37, blue: 0.90)
        ),
        ToolItem(
            icon: "square.split.2x1",
            title: "拼接图片",
            description: "竖向拼接九宫图",
            color: Color(red: 0.31, green: 0.62, blue: 0.98)
        ),
        ToolItem(
            icon: "square.2.layers.3d.top.filled",
            title: "带壳截图",
            description: "让截图娱乐化",
            color: Color(red: 0.3, green: 0.68, blue: 1.0)
        ),
        ToolItem(
            icon: "slider.horizontal.3",
            title: "滤镜特效",
            description: "多种风格滤镜",
            color: Color(red: 1.0, green: 0.44, blue: 0.66)
        ),
        ToolItem(
            icon: "environments.slash.circle",
            title: "传统抠图",
            description: "抠图又快又准",
            color: Color(red: 1.0, green: 0.57, blue: 0.27)
        ),
        ToolItem(
            icon: "camera.badge.clock",
            title: "实景识别",
            description: "识别万物并标注",
            color: Color(red: 0.3, green: 0.83, blue: 0.45)
        ),
        ToolItem(
            icon: "photo.on.rectangle.angled",
            title: "码住安全",
            description: "守护照片隐私安全",
            color: Color(red: 0.1, green: 0.80, blue: 0.88)
        ),
        ToolItem(
            icon: "arrow.up.backward.and.arrow.down.forward",
            title: "尺寸调整",
            description: "批量修改大小",
            color: Color(red: 0.98, green: 0.36, blue: 0.53)
        ),
        ToolItem(
            icon: "sparkles",
            title: "美颜美化",
            description: "智能人像优化",
            color: Color(red: 1.0, green: 0.73, blue: 0.10)
        )
    ]
    
    @Binding private var isPresentingDetail: Bool
    @State private var navigationPath: [Destination] = []
    
    init(isPresentingDetail: Binding<Bool> = .constant(false)) {
        _isPresentingDetail = isPresentingDetail
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // 纯色背景
                Color(red: 0.97, green: 0.97, blue: 0.99)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 头部标题区域
                        VStack(alignment: .leading, spacing: 8) {
                            Text("工具箱")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 1, green: 0.76, blue: 0.02))
                            
                            Text("场景免费，零门槛、更好用")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        // 工具网格 - 3列布局
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 16
                        ) {
                            ForEach(tools) { tool in
                                ToolCard(tool: tool) {
                                    handleSelection(of: tool)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120) // 为底部导航留出空间
                    }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .imageEnhancement:
                    ImageEnhancementView()
                case .framedScreenshot:
                    FramedScreenshotView()
                case .backgroundRemoval:
                    BackgroundRemovalView()
                case .imageStitching:
                    ImageStitchingView()
                case .realTimeRecognition:
                    RealTimeRecognitionView()
                case .safeCode:
                    SafeCodeView()
                }
            }
            .onChange(of: navigationPath) { _, newValue in
                isPresentingDetail = !newValue.isEmpty
            }
            .onAppear {
                isPresentingDetail = !navigationPath.isEmpty
            }
        }
    }
    
    private func handleSelection(of tool: ToolItem) {
        switch tool.title {
        case "画质增强":
            navigationPath.append(.imageEnhancement)
        case "拼接图片":
            navigationPath.append(.imageStitching)
        case "带壳截图":
            navigationPath.append(.framedScreenshot)
        case "传统抠图":
            navigationPath.append(.backgroundRemoval)
        case "实景识别":
            navigationPath.append(.realTimeRecognition)
        case "码住安全":
            navigationPath.append(.safeCode)
        default:
            break
        }
    }
}

// 工具项数据模型
struct ToolItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// 工具卡片组件
struct ToolCard: View {
    let tool: ToolItem
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 点击反馈
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                onTap()
            }
        }) {
            VStack(spacing: 10) {
                // 纯图标 - 极简设计
                Image(systemName: tool.icon)
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(tool.color)
                    .frame(height: 50)
                    .padding(.top, 16)
                
                // 文字信息
                VStack(spacing: 3) {
                    Text(tool.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(tool.description)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(isPressed ? 0.05 : 0.1),
                        radius: isPressed ? 4 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ToolsView()
}
