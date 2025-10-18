//
//  SafeCodeView.swift
//  lovpic
//
//  Created by Codex on 10/14/25.
//

import SwiftUI
import PhotosUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

struct SafeCodeView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var processingMessage: String?
    @State private var processingMessageIsError = false
    @State private var detectionCount: Int = 0
    @State private var isComparing = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false

    private let mosaicScale: CGFloat = 40

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                photoPicker
                previewSection
                statusSection
                actionSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("码住安全")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            loadImage(from: newItem)
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .frame(height: 220)

                if let originalImage {
                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(.accentColor)

                        Text("选择需要打码的图片")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("自动识别条码并添加马赛克")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewSection: some View {
        if originalImage != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("安全预览")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))

                    if let displayImage = displayedImage {
                        Image(uiImage: displayImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        Color.clear
                            .frame(height: 220)
                    }

                    if processedImage != nil {
                        HoldToCompareButton(isActive: isComparing) { pressing in
                            isComparing = pressing
                        }
                        .padding(16)
                    }

                    if isProcessing {
                        ProcessingOverlay()
                    }
                }
                .frame(maxWidth: .infinity)
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let processingMessage {
            Text(processingMessage)
                .font(.system(size: 13))
                .foregroundColor(processingMessageIsError ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if isProcessing {
            Text("正在识别条码并添加马赛克...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if processedImage != nil && detectionCount > 0 {
            Text("提示：按住右下角的对比按钮可以查看原图。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if processedImage != nil {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: saveResultImage) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text(isSaving ? "保存中..." : "保存到本地相册")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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

                if detectionCount == 0 {
                    Text("没有检测到条码或二维码，原图保持不变。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var displayedImage: UIImage? {
        if isComparing {
            return originalImage
        }
        if let processedImage {
            return processedImage
        }
        return originalImage
    }

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    processingMessage = "图片读取失败，请重试。"
                    processingMessageIsError = true
                    originalImage = nil
                    processedImage = nil
                    detectionCount = 0
                }
                return
            }

            let normalizedImage = normalizeOrientation(for: uiImage)

            await MainActor.run {
                originalImage = normalizedImage
                processedImage = nil
                detectionCount = 0
                processingMessage = nil
                processingMessageIsError = false
                saveMessage = nil
                saveMessageIsError = false
                isComparing = false
                isProcessing = true
            }

            runProcessing(on: normalizedImage)
        }
    }

    private func runProcessing(on image: UIImage) {
        Task.detached(priority: .userInitiated) {
            let result = BarcodePrivacyProcessor.process(image: image, mosaicScale: mosaicScale)
            await MainActor.run {
                self.isProcessing = false
                self.saveMessage = nil
                self.saveMessageIsError = false

                switch result {
                case .success(let output):
                    self.processedImage = output.image
                    self.detectionCount = output.count

                    if output.count > 0 {
                        self.processingMessage = "已为 \(output.count) 个条码/二维码添加马赛克。"
                        self.processingMessageIsError = false
                    } else {
                        self.processingMessage = "未检测到条码或二维码，原图未做改动。"
                        self.processingMessageIsError = false
                    }
                case .failure(let error):
                    self.processedImage = nil
                    self.detectionCount = 0
                    self.processingMessage = error.localizedDescription
                    self.processingMessageIsError = true
                }
            }
        }
    }

    private func saveResultImage() {
        guard let processedImage, !isSaving else { return }

        isSaving = true
        saveMessage = nil
        saveMessageIsError = false

        Task {
            let status = await requestPhotoLibraryAccessIfNeeded()
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = true
                    saveMessage = "缺少相册权限，请在系统设置中开启“照片”访问。"
                }
                return
            }

            do {
                try await saveImageToPhotoLibrary(processedImage)
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

    private func normalizeOrientation(for image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? image
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
                    continuation.resume(throwing: BarcodeProcessingError.saveFailed)
                }
            })
        }
    }
}

private struct HoldToCompareButton: View {
    let isActive: Bool
    let onPressChanged: (Bool) -> Void

    var body: some View {
        Image(systemName: isActive ? "eye.fill" : "eye")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 56, height: 56)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50, pressing: { pressing in
                onPressChanged(pressing)
            }, perform: {})
            .accessibilityLabel("按住查看原图")
    }
}

private struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.25))

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        }
        .allowsHitTesting(false)
    }
}

private enum BarcodePrivacyProcessor {
    struct Output {
        let image: UIImage
        let count: Int
    }

    static func process(image: UIImage, mosaicScale: CGFloat) -> Result<Output, BarcodeProcessingError> {
        guard let cgImage = image.cgImage else {
            return .failure(.unableToLoadSource)
        }

        let ciImage = CIImage(cgImage: cgImage)
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return .failure(.detectionFailed(error.localizedDescription))
        }

        let observations = request.results ?? []

        let context = CIContext()
        var mask = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: ciImage.extent)

        for observation in observations {
            let rect = VNImageRectForNormalizedRect(
                observation.boundingBox,
                Int(ciImage.extent.width),
                Int(ciImage.extent.height)
            )

            guard rect.width > 0, rect.height > 0 else { continue }

            let whiteRect = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: rect)
            mask = whiteRect.composited(over: mask)
        }

        if observations.isEmpty {
            return .success(Output(image: image, count: 0))
        }

        let pixelated = ciImage
            .applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: mosaicScale])
            .cropped(to: ciImage.extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = pixelated
        blend.backgroundImage = ciImage
        blend.maskImage = mask

        guard let outputImage = blend.outputImage else {
            return .failure(.blendFailed)
        }

        guard let resultCGImage = context.createCGImage(outputImage, from: ciImage.extent) else {
            return .failure(.outputCreationFailed)
        }

        let resultImage = UIImage(cgImage: resultCGImage, scale: image.scale, orientation: .up)
        return .success(Output(image: resultImage, count: observations.count))
    }
}

private enum BarcodeProcessingError: LocalizedError {
    case unableToLoadSource
    case detectionFailed(String)
    case blendFailed
    case outputCreationFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unableToLoadSource:
            return "无法读取源图像，请尝试其他图片。"
        case .detectionFailed(let message):
            return "识别失败：\(message)"
        case .blendFailed:
            return "图像合成失败，请重试。"
        case .outputCreationFailed:
            return "无法生成处理后的图片，请稍后再试。"
        case .saveFailed:
            return "保存失败，请稍后再试。"
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

#Preview {
    NavigationStack {
        SafeCodeView()
    }
}
