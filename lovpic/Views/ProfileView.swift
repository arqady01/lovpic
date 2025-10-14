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
                        AIUsageCard(
                            remaining: 180,
                            total: 200,
                            label: "剩余用量"
                        )
                        
                        MembershipDaysCard(
                            remainingDays: 28,
                            label: "会员剩余天数"
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

// AI使用仪表盘卡片
struct AIUsageCard: View {
    let remaining: Int  // 剩余次数
    let total: Int      // 总次数
    let label: String
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 仪表盘
            ZStack {
                // 背景灰色刻度
                GaugeShape(progress: 1.0)
                    .stroke(
                        Color.gray.opacity(0.15),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                
                // 进度条
                GaugeShape(progress: percentage)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.45, blue: 0.45),
                                Color(red: 1.0, green: 0.65, blue: 0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                
                // 中间数字
                VStack(spacing: 2) {
                    Text("\(remaining)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("/\(total)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .offset(y: 8)
            }
            .padding(.top, 8)
            
            // 标签
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// 会员剩余天数卡片（滚轮样式）
struct MembershipDaysCard: View {
    let remainingDays: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 16) {
            // 滚轮效果
            ZStack {
                // 滚轮容器（3D效果）
                ZStack {
                    // 遮罩渐变（上下淡出）
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        
                        Spacer()
                        
                        LinearGradient(
                            colors: [Color.clear, Color.white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                    }
                    .frame(width: 100, height: 95)
                    
                    VStack(spacing: 1) {
                        // 最上方数字（3D旋转+几乎不可见）
                        Text("\(remainingDays + 3)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.05))
                            .scaleEffect(0.6)
                            .rotation3DEffect(
                                .degrees(-45),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.3
                            )
                            .blur(radius: 2)
                        
                        // 上方2（3D旋转+非常透明）
                        Text("\(remainingDays + 2)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.2))
                            .scaleEffect(0.75)
                            .rotation3DEffect(
                                .degrees(-30),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.4
                            )
                            .blur(radius: 1.5)
                        
                        // 上方1（3D旋转+半透明）
                        Text("\(remainingDays + 1)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.45))
                            .scaleEffect(0.85)
                            .rotation3DEffect(
                                .degrees(-15),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5
                            )
                            .blur(radius: 0.5)
                        
                        // 中间分隔线（上）
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3),
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.6),
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60, height: 1)
                        
                        // 当前天数（高亮+无旋转）
                        Text("\(remainingDays)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                            .frame(height: 24)
                        
                        // 中间分隔线（下）
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3),
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.6),
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60, height: 1)
                        
                        // 下方1（3D旋转+半透明）
                        Text("\(remainingDays - 1)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.45))
                            .scaleEffect(0.85)
                            .rotation3DEffect(
                                .degrees(15),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5
                            )
                            .blur(radius: 0.5)
                        
                        // 下方2（3D旋转+非常透明）
                        Text("\(remainingDays - 2)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.2))
                            .scaleEffect(0.75)
                            .rotation3DEffect(
                                .degrees(30),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.4
                            )
                            .blur(radius: 1.5)
                        
                        // 最下方数字（3D旋转+几乎不可见）
                        Text("\(remainingDays - 3)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.05))
                            .scaleEffect(0.6)
                            .rotation3DEffect(
                                .degrees(45),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.3
                            )
                            .blur(radius: 2)
                    }
                    .frame(width: 100, height: 95)
                }
                .frame(width: 100, height: 95)
                .mask(
                    Rectangle()
                        .frame(width: 100, height: 95)
                )
            }
            .padding(.top, 12)
            
            // 单位标签
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// 仪表盘形状（半圆弧）
struct GaugeShape: Shape {
    let progress: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + 10)
        let radius = min(rect.width, rect.height) / 2
        
        // 从左侧开始（-180度）到右侧（0度）
        let startAngle = Angle(degrees: 180)
        let endAngle = Angle(degrees: 180 + (180 * progress))
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        return path
    }
}

// 刻度线
struct TickMark: View {
    let index: Int
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 2, height: index % 3 == 0 ? 12 : 8)
            .offset(y: -50)
            .rotationEffect(.degrees(Double(index) * 15 - 90))
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

