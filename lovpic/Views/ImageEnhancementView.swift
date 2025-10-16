//
//  ImageEnhancementView.swift
//  lovpic
//
//  Created by Codex on 10/14/25.
//

import SwiftUI
import UIKit
import Photos
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageEnhancementView: View {
    private enum ScaleOption: String, CaseIterable, Identifiable {
        case two = "2x"
        case three = "3x"
        case four = "4x"
        
        var id: String { rawValue }
        
        var factor: CGFloat {
            switch self {
            case .two: return 2.0
            case .three: return 3.0
            case .four: return 4.0
            }
        }
    }
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var inputImage: UIImage?
    @State private var enhancedImage: UIImage?
    @State private var scaleOption: ScaleOption = .two
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                            )
                            .frame(height: 220)
                        
                        if let uiImage = inputImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus.fill")
                                    .font(.system(size: 38, weight: .medium))
                                    .foregroundColor(.accentColor)
                                
                                Text("选择一张图片")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("支持 JPG / PNG / HEIC")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("放大倍数")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Picker("放大倍数", selection: $scaleOption) {
                        ForEach(ScaleOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Button(action: startEnhancement) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text(isProcessing ? "处理中..." : "开始增强")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .disabled(inputImage == nil || isProcessing)
                .opacity((inputImage == nil || isProcessing) ? 0.6 : 1.0)
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let enhancedImage {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("增强结果预览")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(uiImage: enhancedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
                        
                        if let inputSize = inputImage?.size {
                            let outputSize = enhancedImage.size
                            VStack(alignment: .leading, spacing: 4) {
                                Text("原始尺寸：\(Int(inputSize.width)) × \(Int(inputSize.height)) px")
                                Text("增强尺寸：\(Int(outputSize.width)) × \(Int(outputSize.height)) px")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        }
                        
                        Button(action: saveEnhancedResult) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                                Text(isSaving ? "保存中..." : "保存到相册")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.7 : 1.0)
                        
                        if let saveMessage {
                            Text(saveMessage)
                                .font(.system(size: 12))
                                .foregroundColor(saveMessageIsError ? .red : .green)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("画质增强")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            loadImage(from: newValue)
        }
    }
    
    private func startEnhancement() {
        guard let inputImage else {
            errorMessage = "请先选择需要增强的图片"
            return
        }
        
        errorMessage = nil
        isProcessing = true
        enhancedImage = nil
        saveMessage = nil
        
        Task {
            do {
                let result = try await upscale(image: inputImage, scale: scaleOption.factor)
                
                await MainActor.run {
                    enhancedImage = result
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    errorMessage = "图片读取失败，请重试"
                    inputImage = nil
                    enhancedImage = nil
                    saveMessage = nil
                }
                return
            }
            
            await MainActor.run {
                inputImage = uiImage
                enhancedImage = nil
                errorMessage = nil
                saveMessage = nil
            }
        }
    }
    
    private func upscale(image: UIImage, scale: CGFloat) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let ciInput = CIImage(image: image) else {
                    continuation.resume(throwing: ImageEnhancementError.unableToCreateCIImage)
                    return
                }
                
                let filter = CIFilter.lanczosScaleTransform()
                filter.inputImage = ciInput
                filter.scale = Float(scale)
                filter.aspectRatio = 1.0
                
                guard let filteredImage = filter.outputImage else {
                    continuation.resume(throwing: ImageEnhancementError.unableToProduceOutput)
                    return
                }
                
                let context = CIContext()
                guard let cgImage = context.createCGImage(filteredImage, from: filteredImage.extent) else {
                    continuation.resume(throwing: ImageEnhancementError.unableToCreateCGImage)
                    return
                }
                
                let result = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func saveEnhancedResult() {
        guard let enhancedImage, !isSaving else { return }
        
        isSaving = true
        saveMessage = nil
        saveMessageIsError = false
        
        Task {
            let status = await requestPhotoLibraryAccessIfNeeded()
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = true
                    saveMessage = "缺少相册权限，请在设置中开启“照片”访问。"
                }
                return
            }
            
            do {
                try await saveImageToPhotoLibrary(enhancedImage)
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = false
                    saveMessage = "已保存到系统相册。"
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = true
                    saveMessage = "保存失败，请稍后再试。"
                }
            }
        }
    }
    
    private func requestPhotoLibraryAccessIfNeeded() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if currentStatus == .notDetermined {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        }
        return currentStatus
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: ImageEnhancementError.unableToSaveImage)
                }
            })
        }
    }
}

private enum ImageEnhancementError: LocalizedError {
    case unableToCreateCIImage
    case unableToProduceOutput
    case unableToCreateCGImage
    case unableToSaveImage
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateCIImage:
            return "无法读取源图像，请尝试其他图片。"
        case .unableToProduceOutput:
            return "图像处理失败，请稍后再试。"
        case .unableToCreateCGImage:
            return "无法生成结果图像，请重试。"
        case .unableToSaveImage:
            return "无法保存图片，请稍后再试。"
        }
    }
}

#Preview {
    NavigationStack {
        ImageEnhancementView()
    }
}
