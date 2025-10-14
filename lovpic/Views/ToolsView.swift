//
//  ToolsView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct ToolsView: View {
    let tools = [
        ToolItem(icon: "wand.and.stars", title: "AI增强", color: Color.purple),
        ToolItem(icon: "crop.rotate", title: "裁剪旋转", color: Color.blue),
        ToolItem(icon: "slider.horizontal.3", title: "滤镜特效", color: Color.pink),
        ToolItem(icon: "paintbrush.fill", title: "画笔工具", color: Color.orange),
        ToolItem(icon: "text.bubble.fill", title: "文字标注", color: Color.green),
        ToolItem(icon: "square.on.square", title: "拼图模板", color: Color.indigo)
    ]
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.9, blue: 0.95),
                    Color(red: 0.9, green: 0.95, blue: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    Text("工具")
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    // 工具网格
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(tools) { tool in
                            ToolCard(tool: tool)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // 为底部导航留出空间
                }
            }
        }
    }
}

// 工具项数据模型
struct ToolItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
}

// 工具卡片组件
struct ToolCard: View {
    let tool: ToolItem
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tool.color.opacity(0.6),
                                tool.color.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: tool.icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            
            Text(tool.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: isPressed ? 5 : 15,
                    x: 0,
                    y: isPressed ? 2 : 8
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}

#Preview {
    ToolsView()
}

