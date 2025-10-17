//
//  FramedScreenshotView.swift
//  lovpic
//
//  Created by Codex on 10/14/25.
//

import SwiftUI
import UIKit
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

struct FramedScreenshotView: View {
    @State private var templates: [FrameTemplate] = []
    @State private var selectedTemplate: FrameTemplate?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var userImage: UIImage?
    @State private var framedImage: UIImage?
    @State private var isLoadingTemplates = false
    @State private var hasLoadedTemplates = false
    @State private var loadError: String?
    @State private var selectionError: String?
    @State private var processingError: String?
    @State private var isCompositing = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveMessageIsError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                
                templateSelector
                
                previewSection
                
                resultSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("带壳截图")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            guard !hasLoadedTemplates else { return }
            loadTemplates()
        }
        .onChange(of: selectedTemplate) { _, _ in
            composeIfNeeded()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadUserImage(from: newItem)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择模板，点击手机屏幕区域，将你的图片合成到真实设备中。")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("支持 PNG 屏幕模板，并配套 JSON 定义屏幕区域。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模板选择")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if isLoadingTemplates {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在加载模板...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else if let loadError {
                Text(loadError)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            } else if templates.isEmpty {
                Text("未找到任何模板，请确认 PNG 和 JSON 已添加到 Resources/DeviceFrames 目录并包含在工程中。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(templates) { template in
                            TemplateThumbnail(
                                template: template,
                                isSelected: template.id == selectedTemplate?.id
                            )
                            .onTapGesture {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedTemplate = template
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var previewSection: some View {
        if let template = selectedTemplate {
            VStack(alignment: .leading, spacing: 12) {
                Text("模板预览")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                TemplatePreview(
                    template: template,
                    selectedPhotoItem: $selectedPhotoItem,
                    hasUserImage: userImage != nil,
                    isCompositing: isCompositing
                )
                .frame(height: 480)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                
                Text("提示：点击上方手机屏幕区域，选择需要合成的照片。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if let selectionError {
                    Text(selectionError)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                
                if let processingError {
                    Text(processingError)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private var resultSection: some View {
        if isCompositing {
            HStack(spacing: 12) {
                ProgressView()
                Text("正在生成带壳截图，请稍候...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let framedImage {
            VStack(alignment: .leading, spacing: 16) {
                Text("合成结果")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Image(uiImage: framedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 10)
                
                Button(action: saveCompositeToAlbum) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Image(systemName: "square.and.arrow.down")
                        Text(isSaving ? "保存中..." : "保存到本地相册")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func loadTemplates() {
        isLoadingTemplates = true
        hasLoadedTemplates = true
        
        Task.detached(priority: .userInitiated) {
            do {
                let loaded = try FrameTemplateLoader.loadAll()
                await MainActor.run {
                    self.templates = loaded
                    if self.selectedTemplate == nil {
                        self.selectedTemplate = loaded.first
                    }
                    self.loadError = nil
                    self.isLoadingTemplates = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = error.localizedDescription
                    self.templates = []
                    self.isLoadingTemplates = false
                }
            }
        }
    }
    
    private func loadUserImage(from item: PhotosPickerItem) {
        selectionError = nil
        processingError = nil
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.userImage = image
                        self.selectedPhotoItem = nil
                    }
                    composeIfNeeded()
                } else {
                    await MainActor.run {
                        self.selectionError = "无法读取所选图片，请重试。"
                        self.userImage = nil
                        self.framedImage = nil
                        self.selectedPhotoItem = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.selectionError = "读取图片失败，请重试。"
                    self.userImage = nil
                    self.framedImage = nil
                    self.selectedPhotoItem = nil
                }
            }
        }
    }
    
    private func composeIfNeeded() {
        guard let template = selectedTemplate, let userImage = userImage else {
            framedImage = nil
            return
        }
        
        isCompositing = true
        processingError = nil
        
        Task.detached(priority: .userInitiated) {
            let result = FrameComposer.compose(userImage: userImage, with: template)
            await MainActor.run {
                self.framedImage = result
                self.isCompositing = false
                if result == nil {
                    self.processingError = "合成失败，请检查模板配置是否正确。"
                }
            }
        }
    }
    
    private func saveCompositeToAlbum() {
        guard let framedImage else { return }
        
        saveMessage = nil
        saveMessageIsError = false
        isSaving = true
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: framedImage)
                }) { success, error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        if success {
                            self.saveMessageIsError = false
                            self.saveMessage = "已保存到相册，可以在“最近项目”中查看。"
                        } else {
                            self.saveMessageIsError = true
                            self.saveMessage = "保存失败：\(error?.localizedDescription ?? "未知错误")"
                        }
                    }
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveMessageIsError = true
                    self.saveMessage = "未获得相册写入权限，请在系统设置中授权。"
                }
            case .notDetermined:
                DispatchQueue.main.async {
                    self.isSaving = false
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveMessageIsError = true
                    self.saveMessage = "保存失败：未识别的授权状态。"
                }
            }
        }
    }
}

private struct TemplateThumbnail: View {
    let template: FrameTemplate
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.08), radius: isSelected ? 12 : 6, x: 0, y: isSelected ? 8 : 4)
            
            Image(uiImage: template.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 90, height: 160)
                .padding(12)
        }
        .frame(width: 120, height: 200)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

private struct TemplatePreview: View {
    let template: FrameTemplate
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let hasUserImage: Bool
    let isCompositing: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let layout = TemplateDisplayLayout.make(for: template, in: geometry.size)
            let screenPath = layout.screenPoints.path
            
            ZStack {
                Image(uiImage: template.image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: layout.displayFrame.width, height: layout.displayFrame.height)
                    .position(x: layout.displayFrame.midX, y: layout.displayFrame.midY)
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        screenPath
                            .fill(Color.accentColor.opacity(hasUserImage ? 0.08 : 0.16))
                        
                        screenPath
                            .stroke(Color.accentColor.opacity(isCompositing ? 0.4 : 0.8), lineWidth: hasUserImage ? 1.4 : 2.2)
                        
                        if !hasUserImage {
                            VStack(spacing: 6) {
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("点击屏幕区域")
                                    .font(.system(size: 13, weight: .medium))
                                Text("选择要合成的图片")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(Color.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground).opacity(0.85))
                            )
                            .position(x: layout.screenPoints.center.x, y: layout.screenPoints.center.y)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .contentShape(screenPath)
                .allowsHitTesting(!isCompositing)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                )
            }
        }
    }
}

private struct TemplateDisplayLayout {
    let displayFrame: CGRect
    let screenPoints: ScreenQuad
    
    static func make(for template: FrameTemplate, in containerSize: CGSize) -> TemplateDisplayLayout {
        let aspect = template.aspectRatio
        
        var width = containerSize.width
        var height = width / aspect
        
        if height > containerSize.height {
            height = containerSize.height
            width = height * aspect
        }
        
        let originX = (containerSize.width - width) / 2
        let originY = (containerSize.height - height) / 2
        
        let scaleX = template.config.templateWidth == 0 ? 1 : width / template.config.templateWidth
        let scaleY = template.config.templateHeight == 0 ? 1 : height / template.config.templateHeight
        
        let topLeft = CGPoint(
            x: originX + template.config.leftTopX * scaleX,
            y: originY + template.config.leftTopY * scaleY
        )
        let topRight = CGPoint(
            x: originX + template.config.rightTopX * scaleX,
            y: originY + template.config.rightTopY * scaleY
        )
        let bottomRight = CGPoint(
            x: originX + template.config.rightBottomX * scaleX,
            y: originY + template.config.rightBottomY * scaleY
        )
        let bottomLeft = CGPoint(
            x: originX + template.config.leftBottomX * scaleX,
            y: originY + template.config.leftBottomY * scaleY
        )
        
        let screenPoints = ScreenQuad(
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft
        )
        
        let displayFrame = CGRect(x: originX, y: originY, width: width, height: height)
        
        return TemplateDisplayLayout(displayFrame: displayFrame, screenPoints: screenPoints)
    }
}

private struct FrameTemplate: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let image: UIImage
    let config: FrameTemplateConfig
    
    var aspectRatio: CGFloat {
        guard config.templateHeight != 0 else { return 1 }
        return config.templateWidth / config.templateHeight
    }
    
    static func == (lhs: FrameTemplate, rhs: FrameTemplate) -> Bool {
        lhs.name == rhs.name
    }
}

private struct FrameTemplateConfig: Decodable {
    let leftTopX: CGFloat
    let leftTopY: CGFloat
    let rightTopX: CGFloat
    let rightTopY: CGFloat
    let leftBottomX: CGFloat
    let leftBottomY: CGFloat
    let rightBottomX: CGFloat
    let rightBottomY: CGFloat
    let templateWidth: CGFloat
    let templateHeight: CGFloat
    
    var screenQuad: ScreenQuad {
        ScreenQuad(
            topLeft: CGPoint(x: leftTopX, y: leftTopY),
            topRight: CGPoint(x: rightTopX, y: rightTopY),
            bottomRight: CGPoint(x: rightBottomX, y: rightBottomY),
            bottomLeft: CGPoint(x: leftBottomX, y: leftBottomY)
        )
    }
}

private struct ScreenQuad {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
    
    var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4,
            y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4
        )
    }
    
    var path: Path {
        Path { path in
            path.move(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: bottomRight)
            path.addLine(to: bottomLeft)
            path.closeSubpath()
        }
    }
    
    func averagedAspectRatio() -> CGFloat {
        let topWidth = hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)
        let bottomWidth = hypot(bottomRight.x - bottomLeft.x, bottomRight.y - bottomLeft.y)
        let leftHeight = hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)
        let rightHeight = hypot(bottomRight.x - topRight.x, bottomRight.y - topRight.y)
        let width = (topWidth + bottomWidth) / 2
        let height = (leftHeight + rightHeight) / 2
        guard height > 0 else { return 1 }
        return width / height
    }
}

private enum FrameTemplateLoader {
    enum LoaderError: LocalizedError {
        case resourceNotFound
        case missingConfig(String)
        case missingImage(String)
        case imageDecodeFailed(String)
        case configDecodeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .resourceNotFound:
                return "未能在 Bundle 中找到模板，请确认文件已添加到工程资源。"
            case let .missingConfig(name):
                return "模板 \(name) 缺少同名 JSON 配置文件。"
            case let .missingImage(name):
                return "模板 \(name) 缺少同名 PNG 图片。"
            case let .imageDecodeFailed(name):
                return "无法解析模板图片 \(name)，请检查文件是否损坏。"
            case let .configDecodeFailed(name):
                return "无法解析模板配置 \(name).json，请确认 JSON 字段正确。"
            }
        }
    }
    
    static func loadAll() throws -> [FrameTemplate] {
        let bundle = Bundle.main
        let fileManager = FileManager.default
        
        var jsonURLs: [URL] = []
        if let directJSON = bundle.urls(forResourcesWithExtension: "json", subdirectory: "DeviceFrames") {
            jsonURLs.append(contentsOf: directJSON)
        }
        if let rootJSON = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            jsonURLs.append(contentsOf: rootJSON)
        }
        
        let jsonByName = Dictionary(jsonURLs.map { ($0.deletingPathExtension().lastPathComponent, $0) }) { first, _ in first }
        
        if jsonByName.isEmpty {
            throw LoaderError.resourceNotFound
        }
        
        var templates: [FrameTemplate] = []
        var encounteredError: LoaderError?
        
        for (baseName, jsonURL) in jsonByName.sorted(by: { $0.key < $1.key }) {
            var candidateImageURLs: [URL] = []
            
            let sameFolderImageURL = jsonURL.deletingLastPathComponent().appendingPathComponent("\(baseName).png")
            if fileManager.fileExists(atPath: sameFolderImageURL.path) {
                candidateImageURLs.append(sameFolderImageURL)
            }
            if let subdirectoryImage = bundle.url(forResource: baseName, withExtension: "png", subdirectory: "DeviceFrames") {
                candidateImageURLs.append(subdirectoryImage)
            }
            if let rootImage = bundle.url(forResource: baseName, withExtension: "png") {
                candidateImageURLs.append(rootImage)
            }
            
            guard let imageURL = candidateImageURLs.first else {
                encounteredError = encounteredError ?? .missingImage(baseName)
                continue
            }
            
            guard let image = UIImage(contentsOfFile: imageURL.path) else {
                encounteredError = encounteredError ?? .imageDecodeFailed(baseName)
                continue
            }
            
            do {
                let data = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let config = try decoder.decode(FrameTemplateConfig.self, from: data)
                templates.append(FrameTemplate(name: baseName, image: image, config: config))
            } catch {
                encounteredError = encounteredError ?? .configDecodeFailed(baseName)
            }
        }
        
        if templates.isEmpty {
            throw encounteredError ?? .resourceNotFound
        }
        
        return templates.sorted { $0.name < $1.name }
    }
}

private enum FrameComposer {
    private static let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    
    static func compose(userImage: UIImage, with template: FrameTemplate) -> UIImage? {
        guard let templateCI = ciImage(from: template.image),
              var userCI = ciImage(from: userImage) else {
            return nil
        }
        
        let quad = template.config.screenQuad
        let targetAspect = quad.averagedAspectRatio()
        userCI = crop(image: userCI, toAspectRatio: targetAspect)
        
        let templateExtent = templateCI.extent
        let widthScale = template.config.templateWidth == 0 ? 1 : templateExtent.width / template.config.templateWidth
        let heightScale = template.config.templateHeight == 0 ? 1 : templateExtent.height / template.config.templateHeight
        
        let topLeft = CGPoint(
            x: templateExtent.origin.x + template.config.leftTopX * widthScale,
            y: templateExtent.origin.y + templateExtent.height - template.config.leftTopY * heightScale
        )
        let topRight = CGPoint(
            x: templateExtent.origin.x + template.config.rightTopX * widthScale,
            y: templateExtent.origin.y + templateExtent.height - template.config.rightTopY * heightScale
        )
        let bottomRight = CGPoint(
            x: templateExtent.origin.x + template.config.rightBottomX * widthScale,
            y: templateExtent.origin.y + templateExtent.height - template.config.rightBottomY * heightScale
        )
        let bottomLeft = CGPoint(
            x: templateExtent.origin.x + template.config.leftBottomX * widthScale,
            y: templateExtent.origin.y + templateExtent.height - template.config.leftBottomY * heightScale
        )
        
        let perspective = CIFilter.perspectiveTransform()
        perspective.inputImage = userCI
        perspective.topLeft = topLeft
        perspective.topRight = topRight
        perspective.bottomRight = bottomRight
        perspective.bottomLeft = bottomLeft
        
        guard let warpedUser = perspective.outputImage else {
            return nil
        }
        
        let croppedUser = warpedUser.cropped(to: templateExtent)
        
        let compositor = CIFilter.sourceOverCompositing()
        compositor.inputImage = templateCI
        compositor.backgroundImage = croppedUser
        
        guard let composited = compositor.outputImage?.cropped(to: templateExtent),
              let cgImage = context.createCGImage(composited, from: templateExtent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: template.image.scale, orientation: .up)
    }
    
    private static func ciImage(from image: UIImage) -> CIImage? {
        if let cgImage = image.cgImage {
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            return CIImage(cgImage: cgImage).oriented(orientation)
        } else if let ciImage = image.ciImage {
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            return ciImage.oriented(orientation)
        } else {
            return nil
        }
    }
    
    private static func crop(image: CIImage, toAspectRatio targetAspect: CGFloat) -> CIImage {
        guard targetAspect > 0 else {
            return image
        }
        
        let extent = image.extent
        let currentAspect = extent.width / max(extent.height, 1)
        
        var cropRect = extent
        
        if abs(currentAspect - targetAspect) > 0.01 {
            if currentAspect > targetAspect {
                let newWidth = extent.height * targetAspect
                let originX = extent.origin.x + (extent.width - newWidth) / 2
                cropRect = CGRect(x: originX, y: extent.origin.y, width: newWidth, height: extent.height)
            } else {
                let newHeight = extent.width / targetAspect
                let originY = extent.origin.y + (extent.height - newHeight) / 2
                cropRect = CGRect(x: extent.origin.x, y: originY, width: extent.width, height: newHeight)
            }
        }
        
        let cropped = image.cropped(to: cropRect)
        let translated = cropped.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
        return translated
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
