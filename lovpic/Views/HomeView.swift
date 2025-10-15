//
//  HomeView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI

struct HomeView: View {
    private let backgroundGradient = [
        Color(red: 0.99, green: 0.96, blue: 0.91),
        Color(red: 0.96, green: 0.88, blue: 0.78),
        Color(red: 0.26, green: 0.21, blue: 0.18),
        Color(red: 0.07, green: 0.06, blue: 0.06)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HomeTopBar()
                    HeroSection()
                    PagerIndicator()
                    QuickActionsSection()
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 110)
            }
        }
    }
}

private struct HomeTopBar: View {
    var body: some View {
        HStack(spacing: 12) {
            SearchCapsule()
            CameraButton()
        }
    }
}

private struct SearchCapsule: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
            Text("大字封面")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(Color(red: 0.42, green: 0.33, blue: 0.28))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
    }
}

private struct CameraButton: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "camera.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.36, green: 0.29, blue: 0.25))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.95))
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HeroSection: View {
    var body: some View {
        GeometryReader { proxy in
            let cardWidth = (proxy.size.width - 16) / 2
            HStack(spacing: 16) {
                HeroTextCard()
                    .frame(width: cardWidth, height: proxy.size.height)
                HeroImageCard()
                    .frame(width: cardWidth, height: proxy.size.height)
            }
        }
        .frame(height: 200)
    }
}

private struct HeroTextCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.99, green: 0.94, blue: 0.86),
                        Color(red: 0.96, green: 0.85, blue: 0.7)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("「电商」")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Color(red: 0.5, green: 0.31, blue: 0.2))

                    Text("主图模板")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Color(red: 0.5, green: 0.31, blue: 0.2))

                    Text("E-commerce\nmain image")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.57, green: 0.47, blue: 0.4))
                }

                Button(action: {}) {
                    Text("立即使用")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.39, green: 0.25, blue: 0.2))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [
                                        Color.white,
                                        Color(red: 0.95, green: 0.9, blue: 0.82)
                                    ], startPoint: .top, endPoint: .bottom)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
    }
}

private struct HeroImageCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.99, green: 0.93, blue: 0.82),
                        Color(red: 0.96, green: 0.86, blue: 0.69)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.58), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.61, green: 0.5, blue: 0.32))
                    Text("美图设计室")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.53, green: 0.39, blue: 0.22))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                )

                Spacer(minLength: 0)

                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(colors: [
                                Color(red: 0.98, green: 0.88, blue: 0.7),
                                Color(red: 0.98, green: 0.83, blue: 0.62)
                            ], startPoint: .top, endPoint: .bottom)
                        )

                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 80, height: 80)
                        .offset(x: -18, y: -16)

                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 76, height: 36)
                        .offset(x: 20, y: 26)

                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(Color(red: 0.95, green: 0.68, blue: 0.2))
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 4, y: 8)
                }
                .frame(height: 132)

                VStack(alignment: .leading, spacing: 6) {
                    Text("活动季手价")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.4, blue: 0.23))

                    Text("¥ XX 起/幅")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.38, blue: 0.21))

                    Text("干净配方 原果鲜榨")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.4, blue: 0.23))
                }
            }
            .padding(18)
        }
    }
}

private struct PagerIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(Color.white)
                .frame(width: 22, height: 5)

            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 12, height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }
}

private struct QuickActionsSection: View {
    private let shortcutColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private let shortcuts: [ToolShortcutItem] = [
        ToolShortcutItem(title: "画质修复", icon: "waveform", accent: Color.white, badge: nil),
        ToolShortcutItem(title: "智能抠图", icon: "lasso.and.sparkles", accent: Color.white, badge: nil),
        ToolShortcutItem(title: "AI消除", icon: "eraser.fill", accent: Color.white, badge: nil),
        ToolShortcutItem(
            title: "AI设计",
            icon: "star.square.fill",
            accent: Color.white,
            badge: ShortcutBadge(text: "Agent", background: Color(red: 0.2, green: 0.55, blue: 1.0), foreground: .white)
        ),
        ToolShortcutItem(
            title: "AI图文",
            icon: "pencil.and.outline",
            accent: Color.white,
            badge: ShortcutBadge(text: "自媒体", background: Color(red: 0.98, green: 0.32, blue: 0.36), foreground: .white)
        ),
        ToolShortcutItem(title: "无损改尺寸", icon: "arrow.up.left.and.arrow.down.right", accent: Color.white, badge: nil),
        ToolShortcutItem(title: "AI Logo", icon: "l.square.fill", accent: Color.white, badge: nil),
        ToolShortcutItem(title: "人像背景", icon: "person.crop.rectangle", accent: Color.white, badge: nil)
    ]

    var body: some View {
        LazyVGrid(columns: shortcutColumns, alignment: .center, spacing: 16) {
            ForEach(shortcuts) { shortcut in
                ToolShortcutView(item: shortcut)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.16, green: 0.15, blue: 0.17),
                        Color(red: 0.05, green: 0.05, blue: 0.06)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ToolShortcutView: View {
    let item: ToolShortcutItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.05)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(height: 56)
                    .overlay(
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(item.accent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                if let badge = item.badge {
                    ShortcutBadgeView(badge: badge)
                        .offset(x: 10, y: -12)
                }
            }

            Text(item.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
        }
    }
}

private struct ShortcutBadgeView: View {
    let badge: ShortcutBadge

    var body: some View {
        Text(badge.text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(badge.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badge.background)
            )
            .shadow(color: badge.background.opacity(0.35), radius: 6, x: 0, y: 3)
    }
}

private struct ToolShortcutItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let accent: Color
    let badge: ShortcutBadge?
}

private struct ShortcutBadge {
    let text: String
    let background: Color
    let foreground: Color
}

#Preview {
    HomeView()
}
