//
//  DocumentScannerFeatureView.swift
//  lovpic
//
//  Created by Codex on 2025-01-15.
//

import SwiftUI
import Photos
import VisionKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct DocumentPage: Identifiable, Equatable {
    static func == (lhs: DocumentPage, rhs: DocumentPage) -> Bool {
        lhs.id == rhs.id && lhs.adjustments == rhs.adjustments
    }
    struct Adjustments: Equatable {
        var cropTop: Double = 0
        var cropBottom: Double = 0
        var cropLeft: Double = 0
        var cropRight: Double = 0
        var rotationSteps: Int = 0
        var filter: FilterOption = .natural

        static let `default` = Adjustments()

        func sanitized() -> Adjustments {
            var value = self
            value.cropTop = value.cropTop.clamped(to: 0...0.45)
            value.cropBottom = value.cropBottom.clamped(to: 0...0.45)
            value.cropLeft = value.cropLeft.clamped(to: 0...0.45)
            value.cropRight = value.cropRight.clamped(to: 0...0.45)

            if value.cropTop + value.cropBottom > 0.9 {
                let overflow = value.cropTop + value.cropBottom - 0.9
                value.cropBottom = max(0, value.cropBottom - overflow / 2)
                value.cropTop = max(0, value.cropTop - overflow / 2)
            }
            if value.cropLeft + value.cropRight > 0.9 {
                let overflow = value.cropLeft + value.cropRight - 0.9
                value.cropLeft = max(0, value.cropLeft - overflow / 2)
                value.cropRight = max(0, value.cropRight - overflow / 2)
            }

            value.rotationSteps = ((value.rotationSteps % 4) + 4) % 4
            return value
        }
    }

    enum FilterOption: String, CaseIterable, Identifiable {
        case natural = "原色"
        case mono = "黑白"
        case highContrast = "高对比"
        case inverted = "反色"

        var id: String { rawValue }
    }

    let id = UUID()
    let original: UIImage
    var adjustments: Adjustments
    var edited: UIImage

    init(original: UIImage, adjustments: Adjustments = .default) {
        self.original = original
        self.adjustments = adjustments.sanitized()
        self.edited = DocumentPageRenderer.render(original: original, adjustments: self.adjustments)
    }

    mutating func updateAdjustments(_ newValue: Adjustments) {
        adjustments = newValue.sanitized()
        edited = DocumentPageRenderer.render(original: original, adjustments: adjustments)
    }
}

struct DocumentScannerFeatureView: View {
    @State private var pages: [DocumentPage] = []
    @State private var selectedPageID: DocumentPage.ID?
    @State private var editingIndex: Int?
    @State private var isEditorPresented = false
    @State private var isScannerPresented = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false
    @State private var scannerErrorMessage: String?
    @State private var pendingScanMode: ScanMode = .single

    private enum ScanMode {
        case single
        case multi
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                previewSection
                thumbnailsSection
                statusSection
                actionSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("文档扫描")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isScannerPresented) {
            DocumentScannerController(
                onScan: { images in
                    Task { @MainActor in
                        handleScannedImages(images)
                    }
                },
                onCancel: {
                    isScannerPresented = false
                    scannerErrorMessage = nil
                },
                onFailure: { error in
                    Task { @MainActor in
                        scannerErrorMessage = error.localizedDescription
                        isScannerPresented = false
                    }
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { isEditorPresented },
            set: { newValue in
                isEditorPresented = newValue
                if !newValue { editingIndex = nil }
            }
        )) {
            if let index = editingIndex, pages.indices.contains(index) {
                DocumentPageEditorView(page: $pages[index]) { updatedPage in
                    pages[index] = updatedPage
                    selectedPageID = updatedPage.id
                    saveMessage = "已更新第 \(index + 1) 页，别忘了保存到相册。"
                    saveMessageIsError = false
                }
            } else {
                Text("未找到可编辑的页面").padding()
            }
        }
    }

    private var previewSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                )

            if let page = pages.first(where: { $0.id == selectedPageID }) ?? pages.first {
                Image(uiImage: page.edited)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .transition(.opacity.combined(with: .scale))
                    .onTapGesture {
                        selectedPageID = page.id
                        if let index = pages.firstIndex(where: { $0.id == page.id }) {
                            editingIndex = index
                            isEditorPresented = true
                        }
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.accentColor)

                    Text("等待扫描文档")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("选择下方模式开始扫描，可拍摄单页或多页文档。")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(height: 260)
    }

    private var thumbnailsSection: some View {
        Group {
            if !pages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(pages) { page in
                            let isSelected = page.id == (selectedPageID ?? pages.first?.id)
                            Image(uiImage: page.edited)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 128)
                                .clipped()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.6), lineWidth: isSelected ? 3 : 1)
                                )
                                .overlay(alignment: .topLeading) {
                                    if let index = pages.firstIndex(where: { $0.id == page.id }) {
                                        Text("第 \(index + 1) 页")
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(Color.black.opacity(0.55), in: Capsule())
                                            .foregroundColor(.white)
                                            .padding(6)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .onTapGesture {
                                    selectedPageID = page.id
                                    if let index = pages.firstIndex(where: { $0.id == page.id }) {
                                        editingIndex = index
                                        isEditorPresented = true
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .animation(.easeInOut, value: pages.count)
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            if let scannerErrorMessage {
                Text(scannerErrorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !pages.isEmpty {
                Text("已扫描 \(pages.count) 页文档")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("点击任意缩略图即可编辑旋转角度与滤镜。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isSaving {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("保存到相册中…")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let message = saveMessage {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(saveMessageIsError ? .red : .green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button(action: { startScanning(mode: .single) }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                    Text("单页扫描")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !scannerAvailable)
            .opacity((isSaving || !scannerAvailable) ? 0.75 : 1)

            Button(action: { startScanning(mode: .multi) }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                    Text("多页扫描")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !scannerAvailable)
            .opacity((isSaving || !scannerAvailable) ? 0.75 : 1)

            if !pages.isEmpty {
                Button(action: {
                    Task {
                        let images = pages.map { $0.edited }
                        await saveDocumentsToAlbum(images)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text(isSaving ? "保存中…" : "保存到相册")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(0.9))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .opacity(isSaving ? 0.75 : 1)
            }
        }
    }

    private var scannerAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    private func startScanning(mode: ScanMode) {
        guard scannerAvailable else {
            scannerErrorMessage = "当前设备不支持文档扫描功能。"
            return
        }
        pendingScanMode = mode
        scannerErrorMessage = nil
        saveMessage = nil
        saveMessageIsError = false
        isScannerPresented = true
    }

    private func handleScannedImages(_ images: [UIImage]) {
        let normalized = images.map { $0.normalized() }
        let newPages = normalized.map { DocumentPage(original: $0) }

        switch pendingScanMode {
        case .single:
            pages = Array(newPages.prefix(1))
        case .multi:
            pages.append(contentsOf: newPages)
        }
        isScannerPresented = false
        selectedPageID = (newPages.last ?? pages.first)?.id
        editingIndex = nil
        saveMessage = pages.isEmpty ? "未捕获文档，请重新扫描。" : "扫描完成，共捕获 \(pages.count) 页，点击缩略图进行编辑。"
        saveMessageIsError = false
    }

    private func saveDocumentsToAlbum(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        await MainActor.run {
            isSaving = true
            saveMessage = nil
        }

        do {
            for image in images {
                try await UIImageWriteToSavedPhotosAlbumAsync(image)
            }
            await MainActor.run {
                isSaving = false
                saveMessage = "已保存 \(images.count) 页到相册。"
                saveMessageIsError = false
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveMessage = "保存失败：\(error.localizedDescription)"
                saveMessageIsError = true
            }
        }
    }
}

struct DocumentPageEditorView: View {
    @Binding var page: DocumentPage
    @Environment(\.dismiss) private var dismiss
    @State private var adjustments: DocumentPage.Adjustments
    @State private var previewImage: UIImage
    var onApply: ((DocumentPage) -> Void)?

    init(page: Binding<DocumentPage>, onApply: ((DocumentPage) -> Void)? = nil) {
        _page = page
        let sanitizedAdjustments = page.wrappedValue.adjustments.sanitized()
        _adjustments = State(initialValue: sanitizedAdjustments)
        _previewImage = State(initialValue: DocumentPageRenderer.render(original: page.wrappedValue.original, adjustments: sanitizedAdjustments))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                rotationControls
                filterControls

                Button(role: .none) {
                    adjustments = .default
                    updatePreview()
                } label: {
                    Text("恢复默认设置")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .navigationTitle("编辑文档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        var updatedPage = page
                        updatedPage.updateAdjustments(adjustments)
                        page = updatedPage
                        onApply?(updatedPage)
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: updatePreview)
    }

    private var rotationControls: some View {
        VStack(spacing: 10) {
            Text("旋转角度")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("旋转", selection: Binding(
                get: { adjustments.rotationSteps },
                set: { value in
                    adjustments.rotationSteps = value
                    updatePreview()
                }
            )) {
                Text("0°").tag(0)
                Text("90°").tag(1)
                Text("180°").tag(2)
                Text("270°").tag(3)
            }
            .pickerStyle(.segmented)
        }
    }

    private var filterControls: some View {
        VStack(spacing: 10) {
            Text("滤镜效果")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("滤镜", selection: Binding(
                get: { adjustments.filter },
                set: { newValue in
                    adjustments.filter = newValue
                    updatePreview()
                }
            )) {
                ForEach(DocumentPage.FilterOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func updatePreview() {
        let sanitized = adjustments.sanitized()
        if sanitized != adjustments {
            adjustments = sanitized
        }
        previewImage = DocumentPageRenderer.render(original: page.original, adjustments: sanitized)
    }
}

enum DocumentPageRenderer {
    private static let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])

    static func render(original: UIImage, adjustments: DocumentPage.Adjustments) -> UIImage {
        guard let cgImage = original.cgImage else { return original }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let safe = adjustments.sanitized()

        let cropX = CGFloat(safe.cropLeft) * width
        let cropWidth = max(width * CGFloat(1 - safe.cropLeft - safe.cropRight), 1)
        let cropY = CGFloat(safe.cropBottom) * height
        let cropHeight = max(height * CGFloat(1 - safe.cropTop - safe.cropBottom), 1)

        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        let imageBounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        let integralRect = CGRect(
            x: floor(cropRect.origin.x),
            y: floor(cropRect.origin.y),
            width: ceil(cropRect.size.width),
            height: ceil(cropRect.size.height)
        ).intersection(imageBounds)

        let croppedImage: UIImage
        if integralRect.width >= 1,
           integralRect.height >= 1,
           let croppedCG = cgImage.cropping(to: integralRect) {
            croppedImage = UIImage(cgImage: croppedCG, scale: original.scale, orientation: .up)
        } else {
            croppedImage = original
        }

        let rotated = rotate(image: croppedImage, times: safe.rotationSteps)
        let filtered = apply(filter: safe.filter, to: rotated)
        return filtered
    }

    private static func rotate(image: UIImage, times: Int) -> UIImage {
        let steps = ((times % 4) + 4) % 4
        guard steps != 0, let cgImage = image.cgImage else { return image }

        let angle = CGFloat(steps) * .pi / 2
        var newSize = image.size
        if steps % 2 != 0 {
            newSize = CGSize(width: image.size.height, height: image.size.width)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }

        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: angle)
        context.scaleBy(x: 1, y: -1)

        let drawRect = CGRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )

        context.draw(cgImage, in: drawRect)
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage ?? image
    }

    private static func apply(filter: DocumentPage.FilterOption, to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let output: CIImage
        switch filter {
        case .natural:
            output = ciImage
        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = ciImage
            output = filter.outputImage ?? ciImage
        case .highContrast:
            let controls = CIFilter.colorControls()
            controls.inputImage = ciImage
            controls.contrast = 1.35
            controls.brightness = 0.05
            controls.saturation = 0.9
            output = controls.outputImage ?? ciImage
        case .inverted:
            let invert = CIFilter.colorInvert()
            invert.inputImage = ciImage
            output = invert.outputImage ?? ciImage
        }

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Helpers

private func UIImageWriteToSavedPhotosAlbumAsync(_ image: UIImage) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error {
                continuation.resume(throwing: error)
            } else if success {
                continuation.resume(returning: ())
            } else {
                let failure = NSError(
                    domain: "com.lovpic.app",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "保存失败，未能写入相册。"]
                )
                continuation.resume(throwing: failure)
            }
        }
    }
}

// MARK: - Document Scanner Representable

private struct DocumentScannerController: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void
    var onFailure: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerController

        init(parent: DocumentScannerController) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            defer { controller.dismiss(animated: true) }

            guard scan.pageCount > 0 else {
                let error = NSError(
                    domain: "com.lovpic.app.scanner",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "未捕获任何页面。"]
                )
                parent.onFailure(error)
                return
            }

            var images: [UIImage] = []
            images.reserveCapacity(scan.pageCount)
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            parent.onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            parent.onFailure(error)
        }
    }
}
