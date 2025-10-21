//
//  PhotoScannerFeatureView.swift
//  lovpic
//
//  Created by Codex on 2025-01-17.
//

import SwiftUI

struct PhotoScannerFeatureView: View {
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.99)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "hourglass")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 10)

                VStack(spacing: 10) {
                    Text("功能即将上线")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("我们正在打磨照片扫描体验，敬请期待新版发布。")
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)
                }

                Button {
                    // 保留占位，未来可接入反馈渠道
                } label: {
                    Text("我有功能建议")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(true)
                .opacity(0.4)
            }
        }
        .navigationTitle("照片扫描")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PhotoScannerFeatureView()
    }
}
