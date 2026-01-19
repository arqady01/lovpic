//
//  ImageCropView.swift
//  lovpic
//
//  Created by Kiro on 1/18/26.
//

import SwiftUI
import UIKit
import Photos
import PhotosUI

struct ImageCropView: View {
    // MARK: - 裁切比例模版
    fileprivate enum AspectRatioTemplate: String, CaseIterable, Identifiable {
        case free = "自由"
        case square = "1:1"
        case ratio3x4 = "3:4"
        case ratio4x3 = "4:3"
        case ratio9x16 = "9:16"
        case ratio16x9 = "16:9"
        
        var id: String { rawValue }
        
        var ratio: CGFloat? {
            switch self {
            case .free: return nil
            case .square: return 1.0
            case .ratio3x4: return 3.0 / 4.0
            case .ratio4x3: return 4.0 / 3.0
            case .ratio9x16: return 9.0 / 16.0
            case .ratio16x9: return 16.0 / 9.0
            }
        }
        
        var icon: String {
            switch self {
            case .free: return "crop"
            case .square: return "square"
            case .ratio3x4: return "rectangle.portrait"
            case .ratio4x3: return "rectangle"
            case .ratio9x16: return "rectangle.portrait"
            case .ratio16x9: return "rectangle"
            }
        }
    }
    
    // MARK: - 保存模式
    private enum SaveMode: String, CaseIterable, Identifiable {
        case saveAsNew = "另存为新图片"
        case overwrite = "覆盖原图"
        
        var id: String { rawValue }
    }
    
    // MARK: - State
    @State private var selectedItem: PhotosPickerItem?
    @State private var inputImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var selectedRatio: AspectRatioTemplate = .square
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false
    @State private var showSaveOptions = false
    @State private var selectedSaveMode: SaveMode = .saveAsNew
    
    // 裁切框状态
    @State private var cropRect: CGRect = .zero
    @State private var imageDisplaySize: CGSize = .zero
    @State private var imageOffset: CGSize = .zero
    
    // 原始图片资源引用（用于覆盖保存）
    @State private var originalAsset: PHAsset?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 图片选择区域
                imagePickerSection
                
                // 比例选择区域
                if inputImage != nil {
                    ratioSelectionSection
                }
                
                // 裁切预览区域
                if inputImage != nil {
                    cropPreviewSection
                }
                
                // 操作按钮
                if inputImage != nil {
                    actionButtonsSection
                }
                
                // 错误信息
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 裁切结果预览
                if let croppedImage {
                    resultPreviewSection(croppedImage: croppedImage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("图片裁切")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            loadImage(from: newValue)
        }
        .confirmationDialog("选择保存方式", isPresented: $showSaveOptions, titleVisibility: .visible) {
            Button("另存为新图片") {
                selectedSaveMode = .saveAsNew
                saveCroppedImage()
            }
            Button("覆盖原图") {
                selectedSaveMode = .overwrite
                saveCroppedImage()
            }
            Button("取消", role: .cancel) {}
        }
    }

    
    // MARK: - View Components
    
    private var imagePickerSection: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .frame(height: 180)
                
                if let uiImage = inputImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 180)
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
    }
    
    private var ratioSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("裁切比例")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AspectRatioTemplate.allCases) { ratio in
                        RatioButton(
                            ratio: ratio,
                            isSelected: selectedRatio == ratio
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedRatio = ratio
                                updateCropRect()
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var cropPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("裁切预览")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            GeometryReader { geometry in
                if let image = inputImage {
                    CropOverlayView(
                        image: image,
                        aspectRatio: selectedRatio.ratio,
                        containerSize: geometry.size,
                        onCropRectChanged: { rect, displaySize in
                            cropRect = rect
                            imageDisplaySize = displaySize
                        }
                    )
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
        }
    }
    
    private var actionButtonsSection: some View {
        Button(action: performCrop) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(isProcessing ? "裁切中..." : "开始裁切")
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
    }
    
    private func resultPreviewSection(croppedImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("裁切结果")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Image(uiImage: croppedImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
            
            // 尺寸信息
            if let inputSize = inputImage?.size {
                let outputSize = croppedImage.size
                VStack(alignment: .leading, spacing: 4) {
                    Text("原始尺寸：\(Int(inputSize.width)) × \(Int(inputSize.height)) px")
                    Text("裁切尺寸：\(Int(outputSize.width)) × \(Int(outputSize.height)) px")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            // 保存按钮
            Button(action: { showSaveOptions = true }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(isSaving ? "保存中..." : "保存图片")
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

    
    // MARK: - Methods
    
    private func loadImage(from item: PhotosPickerItem) {
        Task {
            // 获取 PHAsset 引用
            if let assetId = item.itemIdentifier {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                originalAsset = fetchResult.firstObject
            }
            
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    errorMessage = "图片读取失败，请重试"
                    inputImage = nil
                    croppedImage = nil
                    saveMessage = nil
                }
                return
            }
            
            await MainActor.run {
                inputImage = uiImage
                croppedImage = nil
                errorMessage = nil
                saveMessage = nil
            }
        }
    }
    
    private func updateCropRect() {
        // 裁切框会在 CropOverlayView 中自动更新
    }
    
    private func performCrop() {
        guard let inputImage else {
            errorMessage = "请先选择需要裁切的图片"
            return
        }
        
        errorMessage = nil
        isProcessing = true
        croppedImage = nil
        saveMessage = nil
        
        Task {
            do {
                let result = try await cropImage(inputImage, cropRect: cropRect, displaySize: imageDisplaySize)
                
                await MainActor.run {
                    croppedImage = result
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
    
    private func cropImage(_ image: UIImage, cropRect: CGRect, displaySize: CGSize) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(throwing: ImageCropError.unableToCreateCGImage)
                    return
                }
                
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                
                // 计算实际裁切区域（从显示坐标转换到图片坐标）
                let scaleX = imageSize.width / displaySize.width
                let scaleY = imageSize.height / displaySize.height
                
                let actualCropRect = CGRect(
                    x: cropRect.origin.x * scaleX,
                    y: cropRect.origin.y * scaleY,
                    width: cropRect.width * scaleX,
                    height: cropRect.height * scaleY
                )
                
                // 确保裁切区域在图片范围内
                let clampedRect = actualCropRect.intersection(CGRect(origin: .zero, size: imageSize))
                
                guard !clampedRect.isEmpty,
                      let croppedCGImage = cgImage.cropping(to: clampedRect) else {
                    continuation.resume(throwing: ImageCropError.unableToCrop)
                    return
                }
                
                let result = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func saveCroppedImage() {
        guard let croppedImage, !isSaving else { return }
        
        isSaving = true
        saveMessage = nil
        saveMessageIsError = false
        
        Task {
            let status = await requestPhotoLibraryAccess()
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = true
                    saveMessage = "缺少相册权限，请在设置中开启「照片」访问。"
                }
                return
            }
            
            do {
                if selectedSaveMode == .overwrite, let asset = originalAsset {
                    try await overwriteOriginalImage(croppedImage, asset: asset)
                    await MainActor.run {
                        isSaving = false
                        saveMessageIsError = false
                        saveMessage = "已覆盖原图保存。"
                    }
                } else {
                    try await saveImageAsNew(croppedImage)
                    await MainActor.run {
                        isSaving = false
                        saveMessageIsError = false
                        saveMessage = "已保存为新图片。"
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = true
                    saveMessage = "保存失败：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func requestPhotoLibraryAccess() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status)
                }
            }
        }
        return currentStatus
    }
    
    private func saveImageAsNew(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: ImageCropError.unableToSaveImage)
                }
            })
        }
    }
    
    private func overwriteOriginalImage(_ image: UIImage, asset: PHAsset) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            throw ImageCropError.unableToCreateImageData
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest(for: asset)
                request.contentEditingOutput = {
                    let output = PHContentEditingOutput(contentEditingInput: PHContentEditingInput())
                    let adjustmentData = PHAdjustmentData(
                        formatIdentifier: "com.lovpic.crop",
                        formatVersion: "1.0",
                        data: "cropped".data(using: .utf8)!
                    )
                    output.adjustmentData = adjustmentData
                    return output
                }()
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: ImageCropError.unableToOverwriteImage)
                }
            })
        }
    }
}


// MARK: - Supporting Views

/// 比例选择按钮
private struct RatioButton: View {
    let ratio: ImageCropView.AspectRatioTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .light)
            impactMed.impactOccurred()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: ratio.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(ratio.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 裁切遮罩视图
private struct CropOverlayView: View {
    let image: UIImage
    let aspectRatio: CGFloat?
    let containerSize: CGSize
    let onCropRectChanged: (CGRect, CGSize) -> Void
    
    @State private var cropRect: CGRect = .zero
    @State private var imageDisplayRect: CGRect = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var resizeOffset: CGSize = .zero
    @State private var activeCorner: Corner? = nil
    
    fileprivate enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景图片
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(
                        GeometryReader { imageGeometry in
                            Color.clear
                                .onAppear {
                                    calculateImageDisplayRect(containerSize: geometry.size)
                                }
                        }
                    )
                
                // 暗色遮罩
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        CropMaskShape(cropRect: currentCropRect)
                            .fill(style: FillStyle(eoFill: true))
                    )
                
                // 裁切框
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: currentCropRect.width, height: currentCropRect.height)
                    .position(x: currentCropRect.midX, y: currentCropRect.midY)
                
                // 网格线
                CropGridView(rect: currentCropRect)
                
                // 四角拖拽手柄
                ForEach([Corner.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { corner in
                    CornerHandle(corner: corner)
                        .position(cornerPosition(for: corner))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    resizeFromCorner(corner, translation: value.translation)
                                }
                                .onEnded { _ in
                                    finalizeResize()
                                }
                        )
                }
            }
            .onAppear {
                calculateImageDisplayRect(containerSize: geometry.size)
                initializeCropRect()
            }
            .onChange(of: aspectRatio) { _, _ in
                initializeCropRect()
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        moveCropRect(by: value.translation)
                    }
            )
        }
    }
    
    private var currentCropRect: CGRect {
        var rect = cropRect
        rect.origin.x += dragOffset.width
        rect.origin.y += dragOffset.height
        return constrainRect(rect)
    }
    
    private func calculateImageDisplayRect(containerSize: CGSize) {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        var displaySize: CGSize
        if imageAspect > containerAspect {
            displaySize = CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
        } else {
            displaySize = CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
        }
        
        let origin = CGPoint(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2
        )
        
        imageDisplayRect = CGRect(origin: origin, size: displaySize)
    }
    
    private func initializeCropRect() {
        guard imageDisplayRect.width > 0 && imageDisplayRect.height > 0 else { return }
        
        let padding: CGFloat = 20
        let availableWidth = imageDisplayRect.width - padding * 2
        let availableHeight = imageDisplayRect.height - padding * 2
        
        var cropWidth: CGFloat
        var cropHeight: CGFloat
        
        if let ratio = aspectRatio {
            if ratio > availableWidth / availableHeight {
                cropWidth = availableWidth
                cropHeight = cropWidth / ratio
            } else {
                cropHeight = availableHeight
                cropWidth = cropHeight * ratio
            }
        } else {
            cropWidth = availableWidth
            cropHeight = availableHeight
        }
        
        cropRect = CGRect(
            x: imageDisplayRect.midX - cropWidth / 2,
            y: imageDisplayRect.midY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )
        
        // 转换为相对于图片的坐标
        let relativeCropRect = CGRect(
            x: cropRect.origin.x - imageDisplayRect.origin.x,
            y: cropRect.origin.y - imageDisplayRect.origin.y,
            width: cropRect.width,
            height: cropRect.height
        )
        
        onCropRectChanged(relativeCropRect, imageDisplayRect.size)
    }
    
    private func constrainRect(_ rect: CGRect) -> CGRect {
        var constrained = rect
        
        // 确保裁切框在图片范围内
        constrained.origin.x = max(imageDisplayRect.minX, min(constrained.origin.x, imageDisplayRect.maxX - constrained.width))
        constrained.origin.y = max(imageDisplayRect.minY, min(constrained.origin.y, imageDisplayRect.maxY - constrained.height))
        
        return constrained
    }
    
    private func moveCropRect(by translation: CGSize) {
        cropRect.origin.x += translation.width
        cropRect.origin.y += translation.height
        cropRect = constrainRect(cropRect)
        updateCropRectCallback()
    }
    
    private func cornerPosition(for corner: Corner) -> CGPoint {
        let rect = currentCropRect
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
    
    private func resizeFromCorner(_ corner: Corner, translation: CGSize) {
        var newRect = cropRect
        let minSize: CGFloat = 50
        
        switch corner {
        case .topLeft:
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
            newRect.size.width -= translation.width
            newRect.size.height -= translation.height
        case .topRight:
            newRect.origin.y += translation.height
            newRect.size.width += translation.width
            newRect.size.height -= translation.height
        case .bottomLeft:
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
            newRect.size.height += translation.height
        case .bottomRight:
            newRect.size.width += translation.width
            newRect.size.height += translation.height
        }
        
        // 保持最小尺寸
        if newRect.width >= minSize && newRect.height >= minSize {
            // 如果有固定比例，调整尺寸
            if let ratio = aspectRatio {
                let currentRatio = newRect.width / newRect.height
                if currentRatio > ratio {
                    newRect.size.width = newRect.height * ratio
                } else {
                    newRect.size.height = newRect.width / ratio
                }
            }
            
            cropRect = constrainRect(newRect)
        }
    }
    
    private func finalizeResize() {
        updateCropRectCallback()
    }
    
    private func updateCropRectCallback() {
        let relativeCropRect = CGRect(
            x: cropRect.origin.x - imageDisplayRect.origin.x,
            y: cropRect.origin.y - imageDisplayRect.origin.y,
            width: cropRect.width,
            height: cropRect.height
        )
        onCropRectChanged(relativeCropRect, imageDisplayRect.size)
    }
}

/// 裁切遮罩形状
private struct CropMaskShape: Shape {
    let cropRect: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(cropRect)
        return path
    }
}

/// 裁切网格视图
private struct CropGridView: View {
    let rect: CGRect
    
    var body: some View {
        ZStack {
            // 横线
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: rect.width, height: 0.5)
                    .position(x: rect.midX, y: rect.minY + rect.height * CGFloat(i) / 3)
            }
            
            // 竖线
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 0.5, height: rect.height)
                    .position(x: rect.minX + rect.width * CGFloat(i) / 3, y: rect.midY)
            }
        }
    }
}

/// 角落拖拽手柄
private struct CornerHandle: View {
    let corner: CropOverlayView.Corner
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Errors

private enum ImageCropError: LocalizedError {
    case unableToCreateCGImage
    case unableToCrop
    case unableToSaveImage
    case unableToOverwriteImage
    case unableToCreateImageData
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateCGImage:
            return "无法读取源图像，请尝试其他图片。"
        case .unableToCrop:
            return "裁切失败，请调整裁切区域后重试。"
        case .unableToSaveImage:
            return "无法保存图片，请稍后再试。"
        case .unableToOverwriteImage:
            return "无法覆盖原图，已另存为新图片。"
        case .unableToCreateImageData:
            return "无法生成图片数据，请重试。"
        }
    }
}

#Preview {
    NavigationStack {
        ImageCropView()
    }
}
