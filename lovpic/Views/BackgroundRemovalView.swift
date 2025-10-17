//
//  BackgroundRemovalView.swift
//  lovpic
//
//  Created by Codex on 10/15/25.
//

import SwiftUI
import UIKit
import PhotosUI
import Vision
import CoreImage
import Photos

struct BackgroundRemovalView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var cutoutImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false
    @State private var processingTask: Task<Void, Never>?
    @State private var lastProcessedItemIdentifier: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                            )
                            .frame(height: 240)

                        if let image = originalImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .transition(.opacity)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "scissors.badge.ellipsis")
                                    .font(.system(size: 34, weight: .medium))
                                    .foregroundColor(.accentColor)

                                Text("选择一张照片")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("支持 JPG / PNG / HEIC")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if isProcessing {
                            Color.black.opacity(0.35)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            ProgressView("智能抠图中…")
                                .foregroundStyle(.white)
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.black.opacity(0.65))
                                )
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let message = errorMessage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let image = cutoutImage {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("抠图结果预览")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        ZStack {
                            CheckerboardBackground()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 10)

                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(20)
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: saveResult) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                                Text(isSaving ? "保存中…" : "保存到相册")
                                    .font(.system(size: 15, weight: .semibold))
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
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.85 : 1.0)

                        if let saveMessage {
                            Text(saveMessage)
                                .font(.system(size: 12))
                                .foregroundColor(saveMessageIsError ? .red : .green)
                        }
                    }
                } else {
                    Text("选择照片后，系统会自动识别主体并抠出背景。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("传统抠图")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            processSelection(newValue)
        }
        .onDisappear {
            processingTask?.cancel()
        }
    }

    private func processSelection(_ item: PhotosPickerItem) {
        if let identifier = item.itemIdentifier, identifier == lastProcessedItemIdentifier {
            return
        }

        processingTask?.cancel()
        processingTask = Task {
            await MainActor.run {
                errorMessage = nil
                saveMessage = nil
                saveMessageIsError = false
                isProcessing = true
                cutoutImage = nil
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        isProcessing = false
                        errorMessage = "无法读取图片，请重试。"
                        originalImage = nil
                    }
                    return
                }

                guard var image = UIImage(data: data) else {
                    await MainActor.run {
                        isProcessing = false
                        errorMessage = "暂不支持该图片格式，请尝试其他图片。"
                        originalImage = nil
                    }
                    return
                }

                image = image.normalized()

                if Task.isCancelled {
                    await MainActor.run { isProcessing = false }
                    return
                }

                await MainActor.run {
                    originalImage = image
                    lastProcessedItemIdentifier = item.itemIdentifier
                }

                let result = try await generateCutoutImage(from: image)

                if Task.isCancelled {
                    await MainActor.run { isProcessing = false }
                    return
                }

                await MainActor.run {
                    cutoutImage = result
                    isProcessing = false
                }
            } catch {
                if error is CancellationError {
                    await MainActor.run { isProcessing = false }
                    return
                }

                await MainActor.run {
                    cutoutImage = nil
                    isProcessing = false
                    errorMessage = (error as? BackgroundRemovalError)?.errorDescription ?? "抠图失败，请稍后再试。"
                }
            }
        }
    }

    private func saveResult() {
        guard let image = cutoutImage else { return }

        isSaving = true
        saveMessage = nil
        saveMessageIsError = false

        Task {
            let status = await requestPhotoLibraryAccessIfNeeded()

            guard isPhotoAccessAuthorized(status) else {
                await MainActor.run {
                    isSaving = false
                    saveMessageIsError = true
                    saveMessage = "缺少相册权限，请在设置中开启“照片”访问。"
                }
                return
            }

            do {
                try await saveImageToPhotoLibrary(image)
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

    private func generateCutoutImage(from image: UIImage) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try BackgroundRemovalProcessor.cutout(image: image)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func requestPhotoLibraryAccessIfNeeded() async -> PHAuthorizationStatus {
        let currentStatus = currentPhotoAuthorizationStatus()
        if currentStatus == .notDetermined {
            return await requestPhotoAuthorization()
        }
        return currentStatus
    }

    private func currentPhotoAuthorizationStatus() -> PHAuthorizationStatus {
        if #available(iOS 17.0, *) {
            return PHPhotoLibrary.authorizationStatus(for: .addOnly)
        } else {
            return PHPhotoLibrary.authorizationStatus()
        }
    }

    private func requestPhotoAuthorization() async -> PHAuthorizationStatus {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func isPhotoAccessAuthorized(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: BackgroundRemovalError.unableToSaveImage)
                }
            })
        }
    }
}

private struct CheckerboardBackground: View {
    private static let pattern: ImagePaint = {
        let tile: CGFloat = 14
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: tile * 2, height: tile * 2))
        let image = renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: tile * 2, height: tile * 2)))

            UIColor.systemGray4.setFill()
            context.fill(CGRect(x: 0, y: 0, width: tile, height: tile))
            context.fill(CGRect(x: tile, y: tile, width: tile, height: tile))
        }
        return ImagePaint(image: Image(uiImage: image), scale: 1)
    }()

    var body: some View {
        Rectangle()
            .fill(Self.pattern)
    }
}

private enum BackgroundRemovalError: LocalizedError {
    case unableToCreateCGImage
    case noObservation
    case unableToCreateMask
    case unableToCreateResult
    case unableToSaveImage

    var errorDescription: String? {
        switch self {
        case .unableToCreateCGImage:
            return "无法读取图片像素数据，请尝试其他图片。"
        case .noObservation:
            return "未检测到可抠出的主体，请尝试其他照片。"
        case .unableToCreateMask:
            return "生成前景蒙版失败，请稍后再试。"
        case .unableToCreateResult:
            return "无法生成抠图结果，请稍后重试。"
        case .unableToSaveImage:
            return "无法保存图片，请稍后再试。"
        }
    }
}

private enum BackgroundRemovalProcessor {
    static func cutout(image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw BackgroundRemovalError.unableToCreateCGImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw BackgroundRemovalError.noObservation
        }

        let instances = observation.allInstances
        let pixelBuffer = try observation.generateMaskedImage(
            ofInstances: instances,
            from: handler,
            croppedToInstancesExtent: false
        )

        let resultCI = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let resultCGImage = context.createCGImage(resultCI, from: resultCI.extent) else {
            throw BackgroundRemovalError.unableToCreateResult
        }

        return UIImage(cgImage: resultCGImage, scale: image.scale, orientation: .up)
    }
}

private extension UIImage {
    func normalized() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

#Preview {
    NavigationStack {
        BackgroundRemovalView()
    }
}
