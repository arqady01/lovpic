//
//  HomeView.swift
//  lovpic
//
//  Created by mengfs on 10/14/25.
//

import SwiftUI
import UIKit

struct HomeView: View {
    private let backgroundGradient = [
        Color(red: 0.99, green: 0.96, blue: 0.91),
        Color(red: 0.96, green: 0.88, blue: 0.78),
        Color(red: 0.26, green: 0.21, blue: 0.18),
        Color(red: 0.07, green: 0.06, blue: 0.06)
    ]

    @State private var currentBanner = 0

    private let banners: [BannerItem] = [
        BannerItem(
            title: "「电商」主图模板",
            subtitle: "E-commerce main image",
            cta: "立即使用",
            imageName: nil,
            symbolName: "takeoutbag.and.cup.and.straw.fill",
            backgroundGradient: [
                Color(red: 0.99, green: 0.95, blue: 0.87),
                Color(red: 0.96, green: 0.83, blue: 0.67)
            ],
            accentColor: Color(red: 0.93, green: 0.58, blue: 0.2),
            titleColor: Color(red: 0.45, green: 0.29, blue: 0.21),
            subtitleColor: Color(red: 0.57, green: 0.47, blue: 0.4),
            ctaGradient: [Color.white, Color(red: 0.95, green: 0.9, blue: 0.82)]
        ),
        BannerItem(
            title: "AI智能设计",
            subtitle: "智能生成品牌视觉",
            cta: "立即体验",
            imageName: nil,
            symbolName: "sparkles.rectangle.stack.fill",
            backgroundGradient: [
                Color(red: 0.94, green: 0.92, blue: 0.99),
                Color(red: 0.75, green: 0.72, blue: 0.97)
            ],
            accentColor: Color(red: 0.49, green: 0.42, blue: 0.96),
            titleColor: Color(red: 0.32, green: 0.28, blue: 0.6),
            subtitleColor: Color(red: 0.44, green: 0.4, blue: 0.68),
            ctaGradient: [Color.white, Color(red: 0.88, green: 0.84, blue: 0.98)]
        ),
        BannerItem(
            title: "节日主图合集",
            subtitle: "热门节庆一键生成",
            cta: "查看模板",
            imageName: nil,
            symbolName: "giftcard.fill",
            backgroundGradient: [
                Color(red: 0.98, green: 0.9, blue: 0.91),
                Color(red: 0.97, green: 0.76, blue: 0.71)
            ],
            accentColor: Color(red: 0.91, green: 0.39, blue: 0.35),
            titleColor: Color(red: 0.58, green: 0.25, blue: 0.22),
            subtitleColor: Color(red: 0.61, green: 0.36, blue: 0.32),
            ctaGradient: [Color.white, Color(red: 0.97, green: 0.88, blue: 0.86)]
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LinearGradient(colors: backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BannerCarousel(banners: banners, selection: $currentBanner)
                        BannerIndicator(count: banners.count, currentIndex: currentBanner)
                        QuickActionsSection()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct BannerCarousel: View {
    let banners: [BannerItem]
    @Binding var selection: Int

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(banners.enumerated()), id: \.offset) { pair in
                BannerCard(banner: pair.element)
                    .tag(pair.offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 200)
    }
}

private struct BannerCard: View {
    let banner: BannerItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(colors: banner.backgroundGradient,
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(banner.title)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(banner.titleColor)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text(banner.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(banner.subtitleColor)
                        .lineLimit(2)

                    NavigationLink {
                        FeaturePlaceholderView(title: banner.title)
                    } label: {
                        Text(banner.cta)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(banner.titleColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(colors: banner.ctaGradient,
                                                       startPoint: .top,
                                                       endPoint: .bottom)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer(minLength: 0)

                BannerImageView(banner: banner)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .padding(.horizontal, 2)
    }
}

private struct BannerImageView: View {
    let banner: BannerItem
    private let imageSize: CGFloat = 116

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(colors: [
                        banner.accentColor.opacity(0.2),
                        banner.accentColor.opacity(0.1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            contentImage
        }
        .frame(width: imageSize, height: imageSize)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: banner.accentColor.opacity(0.25), radius: 10, x: 0, y: 8)
    }

    @ViewBuilder
    private var contentImage: some View {
        if let name = banner.imageName, let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: imageSize, height: imageSize)
                .clipped()
        } else {
            Image(systemName: banner.symbolName)
                .resizable()
                .scaledToFit()
                .padding(26)
                .foregroundColor(banner.accentColor)
        }
    }
}

private struct BannerIndicator: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: index == currentIndex ? 22 : 12, height: 5)
                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
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
        LazyVGrid(columns: shortcutColumns, alignment: .center, spacing: 24) {
            ForEach(shortcuts) { shortcut in
                NavigationLink {
                    FeaturePlaceholderView(title: shortcut.title)
                } label: {
                    ToolShortcutView(item: shortcut)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
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

private struct BannerItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let cta: String
    let imageName: String?
    let symbolName: String
    let backgroundGradient: [Color]
    let accentColor: Color
    let titleColor: Color
    let subtitleColor: Color
    let ctaGradient: [Color]
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

private struct FeaturePlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)

            Text("该功能正在建设中，敬请期待。")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

#Preview {
    HomeView()
}
