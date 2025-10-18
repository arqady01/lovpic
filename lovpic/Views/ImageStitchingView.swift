//
//  ImageStitchingView.swift
//  lovpic
//
//  Created by Codex on 10/29/25.
//

import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct ImageStitchingView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var stitchAssets: [StitchAsset] = []
    @State private var stitchedImage: UIImage?
    @State private var renderTask: Task<Void, Never>?
    @State private var alertPayload: AlertPayload?
    @State private var isRendering = false
    @State private var isRenderDirty = false
    
    private let minCropSpan: CGFloat = 0.12
    
    var body: some View {
        ScrollViewReader { _ in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if stitchAssets.isEmpty {
                        EmptyStateView(maxCount: 9)
                            .padding(.top, 38)
                    }
                    
                    ForEach(Array(stitchAssets.enumerated()), id: \.element.id) { index, _ in
                        EditableStitchItemView(
                            asset: $stitchAssets[index],
                            index: index,
                            totalCount: stitchAssets.count,
                            minSpan: minCropSpan,
                            onMoveUp: { moveAssetUp(at: index) },
                            onMoveDown: { moveAssetDown(at: index) },
                            onDelete: { removeAsset(at: index) },
                            onCropCommit: { markDirty() }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 140)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomInset
            }
        }
        .navigationTitle("拼接图片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !stitchAssets.isEmpty {
                    Button("清空") {
                        stitchAssets.removeAll()
                        markDirty()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: max(1, 9 - stitchAssets.count),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("添加图片", systemImage: "plus.circle")
                }
                .disabled(stitchAssets.count >= 9)
            }
        }
        .onChange(of: selectedItems, initial: false) {
            handleSelectionChange(selectedItems)
        }
        .onDisappear {
            renderTask?.cancel()
            renderTask = nil
            isRendering = false
        }
        .alert(item: $alertPayload) { payload in
            Alert(title: Text(payload.title),
                  message: Text(payload.message),
                  dismissButton: .default(Text("好的")))
        }
    }
    
    private var bottomInset: some View {
        Group {
            if stitchAssets.isEmpty {
                EmptyView()
            } else {
                ActionBar(
                    stitchedImage: stitchedImage,
                    isRendering: isRendering,
                    isDirty: isRenderDirty,
                    onGenerate: generateStitchedImage,
                    onSave: saveToPhotoLibrary
                )
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial)
            }
        }
    }
    
    private func handleSelectionChange(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let capacity = max(0, 9 - stitchAssets.count)
        guard capacity > 0 else {
            selectedItems.removeAll()
            return
        }
        
        Task {
            var appended: [StitchAsset] = []
            appended.reserveCapacity(capacity)
            
            for item in items.prefix(capacity) {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)?.normalized else {
                    continue
                }
                let preview = await generatePreview(from: image)
                appended.append(StitchAsset(original: image, preview: preview))
            }
            
            await MainActor.run {
                if !appended.isEmpty {
                    stitchAssets.append(contentsOf: appended)
                    markDirty()
                }
                selectedItems.removeAll()
            }
        }
    }
    
    private func generatePreview(from image: UIImage) async -> UIImage {
        await Task.detached(priority: .utility) {
            image.downscaled(maxDimension: 1400)
        }.value
    }
    
    private func removeAsset(at index: Int) {
        guard stitchAssets.indices.contains(index) else { return }
        stitchAssets.remove(at: index)
        markDirty()
    }
    
    private func moveAssetUp(at index: Int) {
        guard index > 0, stitchAssets.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let item = stitchAssets.remove(at: index)
            stitchAssets.insert(item, at: index - 1)
        }
        markDirty()
    }
    
    private func moveAssetDown(at index: Int) {
        guard index < stitchAssets.count - 1, stitchAssets.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let item = stitchAssets.remove(at: index)
            let newIndex = min(index + 1, stitchAssets.count)
            stitchAssets.insert(item, at: newIndex)
        }
        markDirty()
    }
    
    private func markDirty() {
        renderTask?.cancel()
        renderTask = nil
        stitchedImage = nil
        isRendering = false
        isRenderDirty = !stitchAssets.isEmpty
    }
    
    private func generateStitchedImage() {
        guard !stitchAssets.isEmpty else { return }
        guard !isRendering else { return }
        
        let currentAssets = stitchAssets
        let screenScale = UIScreen.main.scale
        
        renderTask?.cancel()
        isRendering = true
        isRenderDirty = false
        stitchedImage = nil
        
        renderTask = Task(priority: .userInitiated) {
            let image = await Task.detached(priority: .userInitiated) {
                ImageStitchingRenderer.stitch(assets: currentAssets, screenScale: screenScale)
            }.value
            
            await MainActor.run {
                if Task.isCancelled {
                    return
                }
                stitchedImage = image
                isRenderDirty = image == nil && !stitchAssets.isEmpty
                isRendering = false
                renderTask = nil
            }
        }
    }
    
    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status.canAddToLibrary else {
                    alertPayload = AlertPayload(
                        title: "保存失败",
                        message: "没有保存照片的权限，请在系统设置中开启相册访问。"
                    )
                    return
                }
                
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                alertPayload = AlertPayload(
                    title: "已保存",
                    message: "拼接图片已保存到系统相册。"
                )
            }
        }
    }
}

// MARK: - Editable Item

private struct EditableStitchItemView: View {
    @Binding var asset: StitchAsset
    let index: Int
    let totalCount: Int
    let minSpan: CGFloat
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onCropCommit: () -> Void
    
    @State private var interaction: CropInteractionMode?
    
    private let cardRadius: CGFloat = 24
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                CropCanvas(
                    image: asset.preview,
                    topFraction: $asset.topCrop,
                    bottomFraction: $asset.bottomCrop,
                    minSpan: minSpan,
                    activeInteraction: $interaction,
                    onCommit: onCropCommit
                )
                .clipShape(RoundedRectangle(cornerRadius: cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                
                Menu {
                    if totalCount > 1 {
                        if index > 0 {
                            Button {
                                onMoveUp()
                            } label: {
                                Label("上移", systemImage: "arrow.up")
                            }
                        }
                        if index < totalCount - 1 {
                            Button {
                                onMoveDown()
                            } label: {
                                Label("下移", systemImage: "arrow.down")
                            }
                        }
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除这张图片", systemImage: "trash")
                    }
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .padding(12)
                }
            }
            
        }
    }
}

private enum CropInteractionMode: String {
    case top
    case middle
    case bottom
}

private struct CropCanvas: View {
    let image: UIImage
    @Binding var topFraction: CGFloat
    @Binding var bottomFraction: CGFloat
    let minSpan: CGFloat
    @Binding var activeInteraction: CropInteractionMode?
    let onCommit: () -> Void
    
    @State private var topStart: CGFloat = 0
    @State private var bottomStart: CGFloat = 1
    @State private var middleStartTop: CGFloat = 0
    @State private var middleStartBottom: CGFloat = 1
    @State private var isDraggingTop = false
    @State private var isDraggingBottom = false
    @State private var isDraggingMiddle = false
    
    private let handleColor = Color(red: 1.0, green: 0.75, blue: 0.05)
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let width = size.width
            let height = size.height
            let topY = topFraction * height
            let bottomY = bottomFraction * height
            let span = max(bottomY - topY, 2)
            let centerY = topY + span / 2
            
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                
                Color.black.opacity(0.42)
                    .frame(height: max(topY, 0))
                    .frame(maxHeight: .infinity, alignment: .top)
                
                Color.black.opacity(0.42)
                    .frame(height: max(height - bottomY, 0))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .blendMode(.plusLighter)
                    .frame(height: span)
                    .offset(y: topY)
                    .allowsHitTesting(false)
                
                cropHandle(
                    baseSymbol: "arrow.up",
                    mode: .top,
                    position: CGPoint(x: width / 2, y: max(topY, 18)),
                    height: height
                )
                
                cropHandle(
                    baseSymbol: "arrow.up.and.down",
                    mode: .middle,
                    position: CGPoint(x: width / 2, y: min(max(centerY, 24), height - 24)),
                    height: height
                )
                
                cropHandle(
                    baseSymbol: "arrow.down",
                    mode: .bottom,
                    position: CGPoint(x: width / 2, y: min(bottomY, height - 18)),
                    height: height
                )
            }
        }
        .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
    }
    
    private func cropHandle(baseSymbol: String,
                            mode: CropInteractionMode,
                            position: CGPoint,
                            height: CGFloat) -> some View {
        let isActive = activeInteraction == mode
        return CropControlButton(
            baseSymbol: baseSymbol,
            activeSymbol: "checkmark",
            isActive: isActive,
            color: handleColor
        )
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if activeInteraction != mode {
                        activate(mode: mode)
                    }
                    
                    guard activeInteraction == mode else { return }
                    
                    switch mode {
                    case .top:
                        adjustTop(with: value, height: height)
                    case .bottom:
                        adjustBottom(with: value, height: height)
                    case .middle:
                        adjustMiddle(with: value, height: height)
                    }
                }
                .onEnded { _ in
                    guard activeInteraction == mode else { return }
                    
                    switch mode {
                    case .top:
                        isDraggingTop = false
                        topStart = topFraction
                    case .bottom:
                        isDraggingBottom = false
                        bottomStart = bottomFraction
                    case .middle:
                        isDraggingMiddle = false
                        middleStartTop = topFraction
                        middleStartBottom = bottomFraction
                    }
                    if mode != .bottom {
                        onCommit()
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if activeInteraction == mode {
                        activeInteraction = nil
                        onCommit()
                    } else {
                        activate(mode: mode)
                    }
                }
        )
        .padding(.vertical, 2)
    }
    
    private func activate(mode: CropInteractionMode) {
        activeInteraction = mode
        switch mode {
        case .top:
            topStart = topFraction
        case .bottom:
            bottomStart = bottomFraction
        case .middle:
            middleStartTop = topFraction
            middleStartBottom = bottomFraction
        }
    }
    
    private func adjustTop(with value: DragGesture.Value, height: CGFloat) {
        guard activeInteraction == .top else {
            activeInteraction = .top
            topStart = topFraction
            return
        }
        
        if !isDraggingTop {
            isDraggingTop = true
            topStart = topFraction
        }
        
        let delta = value.translation.height / height
        let upperBound = (bottomFraction - minSpan).clamped(to: 0...1)
        let candidate = (topStart + delta).clamped(to: 0...upperBound)
        topFraction = candidate
    }
    
    private func adjustBottom(with value: DragGesture.Value, height: CGFloat) {
        guard activeInteraction == .bottom else {
            activeInteraction = .bottom
            bottomStart = bottomFraction
            return
        }
        
        if !isDraggingBottom {
            isDraggingBottom = true
            bottomStart = bottomFraction
        }
        
        let delta = value.translation.height / height
        let lowerBound = (topFraction + minSpan).clamped(to: 0...1)
        let candidate = (bottomStart + delta).clamped(to: lowerBound...1)
        bottomFraction = candidate
    }
    
    private func adjustMiddle(with value: DragGesture.Value, height: CGFloat) {
        guard activeInteraction == .middle else {
            activeInteraction = .middle
            middleStartTop = topFraction
            middleStartBottom = bottomFraction
            return
        }
        
        if !isDraggingMiddle {
            isDraggingMiddle = true
            middleStartTop = topFraction
            middleStartBottom = bottomFraction
        }
        
        let delta = value.translation.height / height
        var newTop = middleStartTop + delta
        var newBottom = middleStartBottom + delta
        let span = max(minSpan, newBottom - newTop)
        
        if newTop < 0 {
            let adjustment = -newTop
            newTop += adjustment
            newBottom += adjustment
        }
        
        if newBottom > 1 {
            let adjustment = newBottom - 1
            newTop -= adjustment
            newBottom -= adjustment
        }
        
        let topUpper = max(0, 1 - span)
        let constrainedTop = newTop.clamped(to: 0...topUpper)
        let lowerBound = (constrainedTop + span).clamped(to: 0...1)
        let constrainedBottom = newBottom.clamped(to: lowerBound...1)
        
        topFraction = constrainedTop
        bottomFraction = constrainedBottom
    }
}

private struct CropControlButton: View {
    let baseSymbol: String
    let activeSymbol: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        Capsule()
            .fill(color.opacity(isActive ? 1 : 0.7))
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .frame(width: 136, height: 40)
            .overlay(
                Image(systemName: isActive ? activeSymbol : baseSymbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.8))
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(isActive ? 1.02 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let maxCount: Int
    
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.split.1x2.fill")
                .font(.system(size: 54, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("当前还没有选中的图片")
                .font(.headline)
            
            Text("点击右上角按钮，选择最多 \(maxCount) 张照片，我们会自动对齐宽度并纵向拼接。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Action Bar

private struct ActionBar: View {
    let stitchedImage: UIImage?
    let isRendering: Bool
    let isDirty: Bool
    let onGenerate: () -> Void
    let onSave: (UIImage) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onGenerate) {
                    if isRendering {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("正在生成…")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label(stitchedImage == nil ? "开始拼图" : "重新生成",
                              systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ActionButtonStyle())
                .disabled(isRendering)
                
                if let image = stitchedImage, !isDirty {
                    Button {
                        onSave(image)
                    } label: {
                        Label("保存到相册", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionButtonStyle())
                } else {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
            }
            
            if isRendering {
                Text("拼接图生成中，请稍候…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if isDirty {
                Text("参数已更新，请重新生成拼接图以预览最新效果。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if stitchedImage == nil {
                Text("生成失败，请重新尝试。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 0.9))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Data Model

private struct StitchAsset: Identifiable, Equatable {
    let id = UUID()
    var original: UIImage
    var preview: UIImage
    var topCrop: CGFloat = 0
    var bottomCrop: CGFloat = 1
    
    static func == (lhs: StitchAsset, rhs: StitchAsset) -> Bool {
        lhs.id == rhs.id &&
        abs(lhs.topCrop - rhs.topCrop) < 0.0001 &&
        abs(lhs.bottomCrop - rhs.bottomCrop) < 0.0001
    }
}

private struct AlertPayload: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ImageTransferable: Transferable {
    let data: Data
    let filename: String
    
    init?(image: UIImage) {
        guard let pngData = image.pngData() else { return nil }
        data = pngData
        filename = "stitched-image.png"
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { transferable in
            transferable.data
        }
        .suggestedFileName { transferable in
            transferable.filename
        }
    }
}

// MARK: - Renderer

private enum ImageStitchingRenderer {
    static func stitch(assets: [StitchAsset], screenScale: CGFloat) -> UIImage? {
        guard !assets.isEmpty else { return nil }
        
        var croppedImages: [UIImage] = []
        croppedImages.reserveCapacity(assets.count)
        
        var targetWidth: CGFloat = .greatestFiniteMagnitude
        
        for asset in assets {
            guard let cgImage = asset.original.normalized.cgImage else { continue }
            let widthPx = cgImage.width
            let heightPx = cgImage.height
            guard widthPx > 0, heightPx > 0 else { continue }
            
            let top = max(0, min(asset.topCrop, asset.bottomCrop - 0.01))
            let bottom = min(1, max(asset.bottomCrop, top + 0.01))
            let topPixel = Int((CGFloat(heightPx) * top).rounded(.down))
            let bottomPixel = Int((CGFloat(heightPx) * bottom).rounded(.up))
            let cropHeight = max(bottomPixel - topPixel, 1)
            
            let cropRect = CGRect(
                x: 0,
                y: topPixel,
                width: widthPx,
                height: cropHeight
            )
            
            guard let croppedCG = cgImage.cropping(to: cropRect) else { continue }
            let croppedImage = UIImage(
                cgImage: croppedCG,
                scale: asset.original.scale,
                orientation: .up
            )
            
            croppedImages.append(croppedImage)
            targetWidth = min(targetWidth, croppedImage.size.width)
        }
        
        guard !croppedImages.isEmpty,
              targetWidth.isFinite,
              targetWidth > 0 else {
            return nil
        }
        
        var scaledImages: [UIImage] = []
        scaledImages.reserveCapacity(croppedImages.count)
        var totalHeight: CGFloat = 0
        
        for image in croppedImages {
            let scaled = image.scaled(toWidth: targetWidth)
            scaledImages.append(scaled)
            totalHeight += scaled.size.height
        }
        
        guard totalHeight > 0 else { return nil }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = screenScale > 0 ? screenScale : UIScreen.main.scale
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetWidth, height: totalHeight),
            format: format
        )
        
        let stitched = renderer.image { _ in
            var offsetY: CGFloat = 0
            for image in scaledImages {
                image.draw(in: CGRect(x: 0, y: offsetY, width: targetWidth, height: image.size.height))
                offsetY += image.size.height
            }
        }
        
        return stitched
    }
}

// MARK: - Helpers

private extension UIImage {
    var normalized: UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func scaled(toWidth width: CGFloat) -> UIImage {
        guard width > 0 else { return self }
        guard abs(size.width - width) > .ulpOfOne else { return self }
        
        let scaleFactor = width / size.width
        let newSize = CGSize(width: width, height: size.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard maxDimension > 0, largestSide > maxDimension else { return self }
        let ratio = maxDimension / largestSide
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private extension PHAuthorizationStatus {
    var canAddToLibrary: Bool {
        switch self {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }
}
