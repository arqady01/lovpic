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
import Foundation

struct SafeCodeView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var processingMessage: String?
    @State private var processingMessageIsError = false
    @State private var barcodeCount: Int = 0
    @State private var sensitiveTextCount: Int = 0
    @State private var isComparing = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false

    private let mosaicScale: CGFloat = 40
    private let sensitiveRules = SensitiveContentRuleSet.default
    
    private var hasMaskedContent: Bool {
        (barcodeCount + sensitiveTextCount) > 0
    }
    
    private var maskedSummaryText: String? {
        let parts = maskedComponents(barcodeCount: barcodeCount, textCount: sensitiveTextCount)
        guard !parts.isEmpty else { return nil }
        return "已打码：" + parts.joined(separator: "、")
    }
    
    private func successSummary(barcodeCount: Int, textCount: Int) -> String {
        let components = maskedComponents(barcodeCount: barcodeCount, textCount: textCount)
        if components.isEmpty {
            return "未检测到条码、二维码或敏感文字，原图未做改动。"
        }
        
        return "已为 " + components.joined(separator: "、") + " 添加马赛克。"
    }
    
    private func maskedComponents(barcodeCount: Int, textCount: Int) -> [String] {
        var parts: [String] = []
        if barcodeCount > 0 {
            parts.append("\(barcodeCount) 个条码/二维码")
        }
        if textCount > 0 {
            parts.append("\(textCount) 处敏感文字")
        }
        return parts
    }

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

                        Text("自动识别条码 / 敏感文字并添加马赛克")
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
            Text("正在识别隐私信息并添加马赛克...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if processedImage != nil && hasMaskedContent {
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

                if let summaryText = maskedSummaryText {
                    Text(summaryText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.system(size: 12))
                        .foregroundColor(saveMessageIsError ? .red : .green)
                }

                if !hasMaskedContent {
                    Text("没有检测到条码、二维码或敏感文字，原图保持不变。")
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
                    barcodeCount = 0
                    sensitiveTextCount = 0
                }
                return
            }

            let normalizedImage = normalizeOrientation(for: uiImage)

            await MainActor.run {
                originalImage = normalizedImage
                processedImage = nil
                barcodeCount = 0
                sensitiveTextCount = 0
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
        let rules = sensitiveRules
        Task.detached(priority: .userInitiated) {
            let result = PrivacyMaskProcessor.process(image: image,
                                                      mosaicScale: mosaicScale,
                                                      rules: rules)
            await MainActor.run {
                self.isProcessing = false
                self.saveMessage = nil
                self.saveMessageIsError = false

                switch result {
                case .success(let output):
                    self.processedImage = output.image
                    self.barcodeCount = output.barcodeCount
                    self.sensitiveTextCount = output.sensitiveTextCount
                    self.processingMessage = successSummary(barcodeCount: output.barcodeCount,
                                                            textCount: output.sensitiveTextCount)
                    self.processingMessageIsError = false
                case .failure(let error):
                    self.processedImage = nil
                    self.barcodeCount = 0
                    self.sensitiveTextCount = 0
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
                    continuation.resume(throwing: PrivacyProcessingError.saveFailed)
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

private enum PrivacyMaskProcessor {
    struct Output {
        let image: UIImage
        let barcodeCount: Int
        let sensitiveTextCount: Int
        
        var totalMaskedCount: Int {
            barcodeCount + sensitiveTextCount
        }
    }
    
    static func process(
        image: UIImage,
        mosaicScale: CGFloat,
        rules: SensitiveContentRuleSet
    ) -> Result<Output, PrivacyProcessingError> {
        guard let cgImage = image.cgImage else {
            return .failure(.unableToLoadSource)
        }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let barcodeRequest = VNDetectBarcodesRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.minimumTextHeight = 0.015
        textRequest.recognitionLanguages = ["zh-Hans", "en-US"]
        
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )
        
        do {
            try handler.perform([barcodeRequest, textRequest])
        } catch {
            return .failure(.detectionFailed(error.localizedDescription))
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        var mask = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: extent)
        var maskedBarcodeCount = 0
        var maskedTextCount = 0
        
        let barcodeObservations = barcodeRequest.results ?? []
        for observation in barcodeObservations {
            let rect = VNImageRectForNormalizedRect(
                observation.boundingBox,
                Int(extent.width),
                Int(extent.height)
            )
            let expanded = padded(rect: rect, in: extent, scale: 0.2)
            guard expanded.width > 0, expanded.height > 0,
                  let whiteRect = whiteMask(for: expanded) else { continue }
            
            mask = whiteRect.composited(over: mask)
            maskedBarcodeCount += 1
        }
        
        if let textObservations = textRequest.results {
            for observation in textObservations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard rules.containsSensitiveText(text) else { continue }
                
                let rect = VNImageRectForNormalizedRect(
                    observation.boundingBox,
                    Int(extent.width),
                    Int(extent.height)
                )
                let expanded = padded(rect: rect, in: extent, scale: 0.35)
                guard expanded.width > 0, expanded.height > 0,
                      let whiteRect = whiteMask(for: expanded) else { continue }
                
                mask = whiteRect.composited(over: mask)
                maskedTextCount += 1
            }
        }
        
        if maskedBarcodeCount == 0 && maskedTextCount == 0 {
            return .success(Output(image: image,
                                   barcodeCount: 0,
                                   sensitiveTextCount: 0))
        }
        
        let pixelated = ciImage
            .applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: mosaicScale])
            .cropped(to: extent)
        
        let blend = CIFilter.blendWithMask()
        blend.inputImage = pixelated
        blend.backgroundImage = ciImage
        blend.maskImage = mask
        
        guard let outputImage = blend.outputImage else {
            return .failure(.blendFailed)
        }
        
        let context = CIContext()
        guard let resultCGImage = context.createCGImage(outputImage, from: extent) else {
            return .failure(.outputCreationFailed)
        }
        
        let resultImage = UIImage(cgImage: resultCGImage, scale: image.scale, orientation: .up)
        return .success(Output(image: resultImage,
                               barcodeCount: maskedBarcodeCount,
                               sensitiveTextCount: maskedTextCount))
    }
    
    private static func padded(rect: CGRect, in extent: CGRect, scale: CGFloat) -> CGRect {
        guard !rect.isNull, !rect.isEmpty else { return .null }
        let basePadding = max(min(extent.width, extent.height) * 0.005, 4)
        let dx = max(rect.width * scale, basePadding)
        let dy = max(rect.height * scale, basePadding)
        let expanded = rect.insetBy(dx: -dx, dy: -dy)
        return expanded.intersection(extent)
    }
    
    private static func whiteMask(for rect: CGRect) -> CIImage? {
        guard !rect.isNull, !rect.isEmpty else { return nil }
        return CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: rect)
    }
}

struct SensitiveContentRuleSet {
    let regexPatterns: [String]
    let keywords: [String]
    
    private let regexes: [NSRegularExpression]
    private let keywordSet: Set<String>
    
    init(regexPatterns: [String], keywords: [String]) {
        self.regexPatterns = regexPatterns
        self.keywords = keywords
        self.regexes = regexPatterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
        }
        self.keywordSet = Set(keywords.map { $0.uppercased() })
    }
    
    static let `default` = SensitiveContentRuleSet(
        regexPatterns: [
            "\\b\\d{6}(19|20)\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])\\d{3}[\\dXx]\\b",
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            "\\b[A-Z]{2}\\d{3,4}\\b"
        ],
        keywords: [
            "身份证号", "证件号", "PASSPORT", "SSN"
        ]
    )
    
    func containsSensitiveText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        let nsText = trimmed as NSString
        let searchRange = NSRange(location: 0, length: nsText.length)
        for regex in regexes where regex.firstMatch(in: trimmed, options: [], range: searchRange) != nil {
            return true
        }
        
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "：", with: "")
            .uppercased()
        
        for keyword in keywordSet where normalized.contains(keyword) {
            return true
        }
        
        return false
    }
    
    func addingRegexPattern(_ pattern: String) -> SensitiveContentRuleSet {
        var patterns = regexPatterns
        patterns.append(pattern)
        return SensitiveContentRuleSet(regexPatterns: patterns, keywords: keywords)
    }
    
    func addingKeyword(_ keyword: String) -> SensitiveContentRuleSet {
        var words = keywords
        words.append(keyword)
        return SensitiveContentRuleSet(regexPatterns: regexPatterns, keywords: words)
    }
}

private enum PrivacyProcessingError: LocalizedError {
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
