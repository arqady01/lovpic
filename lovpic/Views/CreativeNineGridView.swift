//
//  CreativeNineGridView.swift
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

struct CreativeNineGridView: View {
    private enum CreationStep: Int {
        case selection
        case layout
        
        var title: String {
            switch self {
            case .selection: return "选择素材"
            case .layout: return "创意九宫格"
            }
        }
    }
    
    fileprivate enum PickerPhase {
        case main
        case small
    }
    
    @State private var step: CreationStep = .selection
    
    @State private var mainPhoto: SelectedPhoto?
    @State private var smallPhotos: [SelectedPhoto] = []
    @State private var croppedSmallImages: [UIImage] = []
    @State private var subjectCutout: UIImage?
    @State private var subjectTransform = SubjectTransform()
    
    @State private var pickerPhase: PickerPhase = .main
    @State private var pendingMainPickerItem: PhotosPickerItem?
    @State private var pendingSmallPickerItems: [PhotosPickerItem] = []
    @State private var isLoadingSelectedPhoto = false
    @State private var selectionError: CreativeNineGridError?
    
    @State private var isRunningSegmentation = false
    @State private var segmentationError: CreativeNineGridError?
    
    // Cropping queue
    @State private var cropQueue: [CropTask] = []
    @State private var activeCropTask: CropTask?
    @State private var activeCropState = CropState()
    @State private var cropProcessingError: CreativeNineGridError?
    
    // Layout
    @State private var layoutOrientation: LShapeOrientation = .openingBottomRight
    private let gridSpacing: Double = 15
    @State private var isExporting = false
    @State private var exportAlert: CreativeNineGridError?
    
    private let subjectSegmenter = PersonSegmenter()
    private let cropRenderer = CropRenderer()
    private let layoutRenderer = NineGridRenderer()
    
    var body: some View {
        content
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .layout {
                        Button("返回重选") {
                            resetToSelection()
                        }
                    }
                }
            }
            .alert(item: $selectionError) { payload in
                Alert(title: Text(payload.title), message: Text(payload.message ?? ""), dismissButton: .default(Text("好的")))
            }
            .alert(item: $segmentationError) { payload in
                Alert(title: Text(payload.title), message: Text(payload.message ?? ""), dismissButton: .default(Text("重新选择"), action: {
                    resetToSelection()
                }))
            }
            .alert(item: $cropProcessingError) { payload in
                Alert(title: Text(payload.title), message: Text(payload.message ?? ""), dismissButton: .default(Text("好的")))
            }
            .alert(item: $exportAlert) { payload in
                Alert(title: Text(payload.title), message: Text(payload.message ?? ""), dismissButton: .default(Text("好的")))
            }
            .sheet(item: $activeCropTask, onDismiss: {
                Task { @MainActor in
                    presentNextCropTaskIfNeeded()
                }
            }) { task in
                SmallPhotoCropModal(
                    image: task.image,
                    cropState: $activeCropState,
                    onCancel: {
                        Task { @MainActor in
                            cancelCurrentCropTask()
                        }
                    },
                    onConfirm: { state in
                        Task {
                            await finalizeCrop(task: task, with: state)
                        }
                    }
                )
            }
    }
}

// MARK: - Main Content

private extension CreativeNineGridView {
    @ViewBuilder
    var content: some View {
        switch step {
        case .selection:
            selectionContent
        case .layout:
            layoutContent
        }
    }

    @ViewBuilder
    private var selectionContent: some View {
        SelectionStepView(
            mainPhoto: mainPhoto,
            smallPhotos: smallPhotos,
            pickerPhase: pickerPhase,
            pendingMainPickerItem: $pendingMainPickerItem,
            pendingSmallPickerItems: $pendingSmallPickerItems,
            isLoadingSelectedPhoto: isLoadingSelectedPhoto,
            isCroppingInProgress: isCroppingInProgress,
            isRunningSegmentation: isRunningSegmentation,
            onDeleteSmall: { index in
                deleteSmallPhoto(at: index)
            },
            onDeleteMain: {
                resetMainPhoto()
            },
            onReplaceSmall: { index, item in
                handleSmallReplacement(item, at: index)
            },
            onAddSmallFromPlaceholder: { item in
                handleSingleSmallAddition(item)
            },
            canProceed: canProceedToLayout,
            onNext: proceedToLayout
        )
        .onChange(of: pendingMainPickerItem) { newValue in
            guard let item = newValue else { return }
            handleMainSelection(item)
        }
        .onChange(of: pendingSmallPickerItems) { newItems in
            guard !newItems.isEmpty else { return }
            handleSmallBatchSelection(newItems)
        }
    }

    @ViewBuilder
    private var layoutContent: some View {
            LayoutStepView(
                croppedImages: $croppedSmallImages,
                subjectCutout: subjectCutout,
                orientation: $layoutOrientation,
                spacing: gridSpacing,
                subjectTransform: $subjectTransform,
                isExporting: isExporting,
                onReorder: reorderSmallImages,
                onExport: exportComposition
            )
    }
}

// MARK: - Step Helpers

private extension CreativeNineGridView {
    @MainActor
    func resetToSelection() {
        step = .selection
        pickerPhase = mainPhoto == nil ? .main : .small
        croppedSmallImages = []
        cropQueue.removeAll()
        activeCropTask = nil
        activeCropState = CropState()
        cropProcessingError = nil
        pendingMainPickerItem = nil
        pendingSmallPickerItems = []
        isLoadingSelectedPhoto = false
        subjectTransform = SubjectTransform()
    }
    
    @MainActor
    func resetMainPhoto() {
        mainPhoto = nil
        subjectCutout = nil
        segmentationError = nil
        pickerPhase = .main
        subjectTransform = SubjectTransform()
    }
    
    @MainActor
    func deleteSmallPhoto(at index: Int) {
        guard smallPhotos.indices.contains(index) else { return }
        smallPhotos.remove(at: index)
        syncCroppedImages()
        if pickerPhase != .main {
            pickerPhase = .small
        }
    }
    
    @MainActor
    func reorderSmallImages(from source: Int, to destination: Int) {
        guard source != destination else { return }
        guard smallPhotos.indices.contains(source), smallPhotos.indices.contains(destination) else { return }
        smallPhotos.swapAt(source, destination)
        if croppedSmallImages.indices.contains(source), croppedSmallImages.indices.contains(destination) {
            croppedSmallImages.swapAt(source, destination)
        }
    }
    
    func handleMainSelection(_ item: PhotosPickerItem) {
        Task {
            await processMainSelection(item)
        }
    }
    
    func handleSmallBatchSelection(_ items: [PhotosPickerItem]) {
        Task {
            await processSmallSelections(items, replacingIndex: nil)
        }
    }
    
    func handleSmallReplacement(_ item: PhotosPickerItem, at index: Int) {
        guard smallPhotos.indices.contains(index) else { return }
        Task {
            await processSmallSelections([item], replacingIndex: index)
        }
    }
    
    func handleSingleSmallAddition(_ item: PhotosPickerItem) {
        guard smallPhotos.count < 5 else { return }
        Task {
            await processSmallSelections([item], replacingIndex: nil)
        }
    }
    
    private func processMainSelection(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isLoadingSelectedPhoto = true
            selectionError = nil
        }
        
        let image = await item.loadUIImage()
        
        await MainActor.run {
            isLoadingSelectedPhoto = false
            pendingMainPickerItem = nil
        }
        
        guard let image else {
            await MainActor.run {
                selectionError = CreativeNineGridError(
                    title: "加载失败",
                    message: "无法读取这张图片，请重试。"
                )
            }
            return
        }
        
        await MainActor.run {
            mainPhoto = SelectedPhoto(image: image)
            pickerPhase = .small
        }
        
        await runSegmentation(for: image)
    }
    
    private func processSmallSelections(_ items: [PhotosPickerItem], replacingIndex index: Int?) async {
        guard !items.isEmpty else {
            await MainActor.run {
                pendingSmallPickerItems = []
            }
            return
        }
        
        var loadedImages: [UIImage] = []
        loadedImages.reserveCapacity(items.count)
        
        await MainActor.run {
            isLoadingSelectedPhoto = true
        }
        
        for item in items {
            if let image = await item.loadUIImage() {
                loadedImages.append(image)
            }
        }
        
        await MainActor.run {
            pendingSmallPickerItems = []
            isLoadingSelectedPhoto = false
        }
        
        guard !loadedImages.isEmpty else {
            await MainActor.run {
                selectionError = CreativeNineGridError(
                    title: "加载失败",
                    message: "无法读取所选图片，请重试。"
                )
            }
            return
        }
        
        await MainActor.run {
            enqueueCropTasks(with: loadedImages, replacingIndex: index)
        }
    }
    
    @MainActor
    func runSegmentation(for image: UIImage) async {
        isRunningSegmentation = true
        segmentationError = nil
        defer { isRunningSegmentation = false }
        do {
            let cutout = try await subjectSegmenter.generateSubjectCutout(from: image)
            subjectCutout = cutout.trimmedToOpaqueBounds()
            subjectTransform = SubjectTransform()
        } catch {
            segmentationError = CreativeNineGridError(
                title: "抠图失败",
                message: "无法识别主体，请尝试更换轮廓清晰的照片。"
            )
            subjectCutout = nil
        }
    }
    
    @MainActor
    private func enqueueCropTasks(with images: [UIImage], replacingIndex index: Int?) {
        selectionError = nil
        var tasks: [CropTask] = []
        
        if let replaceIndex = index {
            if let first = images.first, smallPhotos.indices.contains(replaceIndex) {
                tasks.append(CropTask(image: first, replaceIndex: replaceIndex))
            } else if let first = images.first {
                let safeIndex = min(replaceIndex, smallPhotos.count)
                tasks.append(CropTask(image: first, replaceIndex: safeIndex))
            }
        } else {
            for image in images where smallPhotos.count + tasks.count < 5 {
                tasks.append(CropTask(image: image, replaceIndex: nil))
            }
        }
        
        guard !tasks.isEmpty else { return }
        cropQueue.append(contentsOf: tasks)
        presentNextCropTaskIfNeeded()
    }
    
    @MainActor
    private func presentNextCropTaskIfNeeded() {
        guard activeCropTask == nil, !cropQueue.isEmpty else { return }
        activeCropState = CropState()
        activeCropTask = cropQueue.removeFirst()
    }
    
    @MainActor
    private func cancelCurrentCropTask() {
        activeCropTask = nil
        presentNextCropTaskIfNeeded()
    }
    
    private func finalizeCrop(task: CropTask, with state: CropState) async {
        let cropped = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            cropRenderer.cropSquare(image: task.image, state: state)
        }.value
        
        await MainActor.run {
            if let cropped {
                applyCroppedImage(cropped, replacingIndex: task.replaceIndex)
            } else {
                cropProcessingError = CreativeNineGridError(
                    title: "裁剪失败",
                    message: "生成裁剪图时出现问题，请重试。"
                )
            }
            activeCropTask = nil
            presentNextCropTaskIfNeeded()
        }
    }
    
    @MainActor
    private func applyCroppedImage(_ image: UIImage, replacingIndex index: Int?) {
        if let replaceIndex = index, smallPhotos.indices.contains(replaceIndex) {
            smallPhotos[replaceIndex] = SelectedPhoto(image: image)
        } else if smallPhotos.count < 5 {
            smallPhotos.append(SelectedPhoto(image: image))
        }
        pickerPhase = .small
        syncCroppedImages()
    }
    
    @MainActor
    private func syncCroppedImages() {
        croppedSmallImages = smallPhotos.map(\.image)
    }
    
    private var isCroppingInProgress: Bool {
        activeCropTask != nil || !cropQueue.isEmpty
    }
    
    var canProceedToLayout: Bool {
        mainPhoto != nil &&
        subjectCutout != nil &&
        smallPhotos.count == 5 &&
        !isLoadingSelectedPhoto &&
        !isRunningSegmentation &&
        !isCroppingInProgress
    }
    
    @MainActor
    func proceedToLayout() {
        guard canProceedToLayout else { return }
        syncCroppedImages()
        step = .layout
    }
    
    @MainActor
    func exportComposition() {
        guard !croppedSmallImages.isEmpty else { return }
        isExporting = true
        exportAlert = nil
        
        Task {
            let rendered = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                layoutRenderer.renderNineGrid(
                    smallImages: croppedSmallImages,
                    subject: subjectCutout,
                    orientation: layoutOrientation,
                    spacing: CGFloat(gridSpacing),
                    subjectTransform: subjectTransform
                )
            }.value
            
            await MainActor.run {
                isExporting = false
                guard let rendered else {
                    exportAlert = CreativeNineGridError(
                        title: "导出失败",
                        message: "生成九宫格时出现问题，请稍后重试。"
                    )
                    return
                }
                saveCompositeToLibrary(rendered)
            }
        }
    }
    
    @MainActor
    func saveCompositeToLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status.canAddToLibrary else {
                    exportAlert = CreativeNineGridError(
                        title: "无法保存",
                        message: "请在系统设置中开启相册访问权限。"
                    )
                    return
                }
                
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                exportAlert = CreativeNineGridError(
                    title: "已保存",
                    message: "已将创意九宫格保存至系统相册。"
                )
            }
        }
    }
}

// MARK: - Step Views

private struct SelectionStepView: View {
    let mainPhoto: SelectedPhoto?
    let smallPhotos: [SelectedPhoto]
    let pickerPhase: CreativeNineGridView.PickerPhase
    @Binding var pendingMainPickerItem: PhotosPickerItem?
    @Binding var pendingSmallPickerItems: [PhotosPickerItem]
    let isLoadingSelectedPhoto: Bool
    let isCroppingInProgress: Bool
    let isRunningSegmentation: Bool
    let onDeleteSmall: (Int) -> Void
    let onDeleteMain: () -> Void
    let onReplaceSmall: (Int, PhotosPickerItem) -> Void
    let onAddSmallFromPlaceholder: (PhotosPickerItem) -> Void
    let canProceed: Bool
    let onNext: () -> Void
    
    private var instructionText: String {
        switch pickerPhase {
        case .main:
            return "请先选择 1 张主图"
        case .small:
            let selected = smallPhotos.count
            let remaining = max(0, 5 - selected)
            if remaining == 0 {
                return "已选择 5 张小图，可进入下一步"
            } else if selected == 0 {
                return "请继续选择 5 张小图"
            } else {
                return "已选择 \(selected) 张小图，还需 \(remaining) 张"
            }
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                VStack(spacing: 8) {
                    Text("Step 1 · 选择素材")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.primary)
                    
                    Text(instructionText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("每张小图会在选择后立刻进入裁剪流程")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                PhotosPicker(
                    selection: $pendingMainPickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    MainPhotoCard(
                        photo: mainPhoto,
                        isProcessing: isRunningSegmentation || isLoadingSelectedPhoto,
                        onDelete: onDeleteMain
                    )
                }
                .disabled(isRunningSegmentation || isLoadingSelectedPhoto || isCroppingInProgress)
                
                SmallPhotosGrid(
                    photos: smallPhotos,
                    isLoading: (isLoadingSelectedPhoto && pickerPhase == .small) || isCroppingInProgress,
                    onDelete: onDeleteSmall,
                    onReplace: onReplaceSmall,
                    onAdd: onAddSmallFromPlaceholder
                )
                if isCroppingInProgress {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在裁剪所选图片…")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 14) {
                    PhotosPicker(
                        selection: $pendingSmallPickerItems,
                        maxSelectionCount: max(0, 5 - smallPhotos.count),
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            pickerPhase == .main ? "请先选择主图" : "批量选择小图",
                            systemImage: "photo.fill.on.rectangle.fill"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                        )
                    }
                    .disabled(
                        isLoadingSelectedPhoto ||
                        isRunningSegmentation ||
                        isCroppingInProgress ||
                        pickerPhase == .main ||
                        smallPhotos.count >= 5
                    )
                    .buttonStyle(.plain)
                    
                    Button(action: onNext) {
                        Text("进入布局设计")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(canProceed ? Color.accentColor : Color.gray.opacity(0.5))
                            )
                    }
                    .disabled(!canProceed)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                VStack(spacing: 12) {
                    Text("提示")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("主图主体请尽量清晰、完整，以提升抠图效果。")
                        } icon: {
                            Image(systemName: "1.circle")
                                .foregroundColor(.blue)
                        }
                        Label {
                            Text("小图可以按场景、色调组合，后续还可调整裁剪。")
                        } icon: {
                            Image(systemName: "2.circle")
                                .foregroundColor(.blue)
                        }
                        Label {
                            Text("若提示权限不足，可前往系统设置开启相册访问。")
                        } icon: {
                            Image(systemName: "3.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .labelStyle(InstructionLabelStyle())
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .padding(.horizontal, 20)
                
                .padding(.bottom, 12)
                if !canProceed {
                    Text("完成主图抠图并裁剪 5 张小图后即可进入布局")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

private struct MainPhotoCard: View {
    let photo: SelectedPhoto?
    let isProcessing: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主图")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
            
            ZStack {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                
                if let image = photo?.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipped()
                    .clipShape(Rectangle())
                        .overlay(alignment: .topTrailing) {
                            Button {
                                onDelete()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            }
                            .padding(18)
                        }
                        .overlay {
                            if isProcessing {
                                ProgressOverlay()
                            }
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: 42))
                            .foregroundColor(Color.secondary.opacity(0.6))
                        Text("暂未选择主图")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 220)
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 20)
        }
    }
}

private struct SmallPhotosGrid: View {
    let photos: [SelectedPhoto]
    let isLoading: Bool
    let onDelete: (Int) -> Void
    let onReplace: (Int, PhotosPickerItem) -> Void
    let onAdd: (PhotosPickerItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("小图（需 5 张）")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, item in
                    PhotosPicker(
                        selection: Binding<PhotosPickerItem?>(
                            get: { nil },
                            set: { newValue in
                                guard let pickerItem = newValue else { return }
                                onReplace(index, pickerItem)
                            }
                        ),
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        ZStack {
                            Image(uiImage: item.image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 104)
                            .clipShape(Rectangle())
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        onDelete(index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.white)
                                            .shadow(radius: 3)
                                    }
                                    .padding(10)
                                }
                        }
                    }
                    .disabled(isLoading)
                }
                
                if photos.count < 5 {
                    ForEach(photos.count..<5, id: \.self) { _ in
                        PhotosPicker(
                            selection: Binding<PhotosPickerItem?>(
                                get: { nil },
                                set: { newValue in
                                    guard let pickerItem = newValue else { return }
                                    onAdd(pickerItem)
                                }
                            ),
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Rectangle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(height: 104)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 22))
                                            .foregroundColor(.secondary)
                                        Text("等待添加")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .overlay {
                if isLoading {
                    ProgressOverlay()
                }
            }
        }
    }
}

private struct SmallPhotoCropModal: View {
    let image: UIImage
    @Binding var cropState: CropState
    let onCancel: () -> Void
    let onConfirm: (CropState) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("调整小图裁剪")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.top, 12)
                
                SquareCropperView(image: image, cropState: $cropState)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("双指缩放，单指拖动调整画面", systemImage: "hand.draw")
                    Label("确保主体居中填满，避免留白", systemImage: "crop")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .labelStyle(InstructionLabelStyle())
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onConfirm(cropState)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct LayoutStepView: View {
    @Binding var croppedImages: [UIImage]
    let subjectCutout: UIImage?
    @Binding var orientation: LShapeOrientation
    let spacing: Double
    @Binding var subjectTransform: SubjectTransform
    let isExporting: Bool
    let onReorder: (Int, Int) -> Void
    let onExport: () -> Void
    
    var body: some View {
        let spacingValue = CGFloat(spacing)
        VStack(spacing: 22) {
            ScrollView {
                VStack(spacing: 26) {
                    Text("Step 2 · 创意布局")
                        .font(.system(size: 22, weight: .heavy))
                        .padding(.top, 16)
                    
                    NineGridPreview(
                        images: $croppedImages,
                        subject: subjectCutout,
                        orientation: orientation,
                        spacing: spacingValue,
                        subjectTransform: $subjectTransform,
                        isInteractive: subjectCutout != nil,
                        onReorder: onReorder
                    )
                    .frame(height: 360)
                    .padding(.horizontal, 24)
                    .overlay {
                        if croppedImages.contains(where: { $0.size.width < 600 || $0.size.height < 600 }) {
                            VStack {
                                Spacer()
                                LowResolutionWarning()
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 18) {
                        Text("布局方向")
                            .font(.system(size: 16, weight: .semibold))
                        LayoutOrientationPicker(selection: $orientation)
                    }
                    .padding(.horizontal, 24)
                    
                    if subjectCutout != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("主体拖放")
                                .font(.system(size: 16, weight: .semibold))
                            Text("在上方九宫格中用单指拖动主体位置，双指缩放调整大小。")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Button {
                                subjectTransform = SubjectTransform()
                            } label: {
                                Label("重置主体", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.accentColor.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }

                    if subjectCutout == nil {
                        MissingSubjectWarning()
                            .padding(.horizontal, 24)
                    }
                    
                    Button(action: onExport) {
                        HStack {
                            if isExporting {
                                ProgressView()
                            }
                            Text(isExporting ? "正在导出..." : "保存到相册")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(isExporting ? Color.gray.opacity(0.6) : Color.accentColor)
                        )
                    }
                    .disabled(isExporting)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Preview Components

private struct NineGridPreview: View {
    @Binding var images: [UIImage]
    let subject: UIImage?
    let orientation: LShapeOrientation
    let spacing: CGFloat
    @Binding var subjectTransform: SubjectTransform
    let isInteractive: Bool
    let onReorder: (Int, Int) -> Void
    
    @State private var activeDrag: ActiveDrag?
    @State private var dropTarget: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let cellSize = orientation.cellSize(for: size, spacing: spacing)
            let offsets = orientation.cellOffsets(cellSize: cellSize, spacing: spacing)
            let centers = offsets.map { $0.position() }
            
            ZStack {
                ForEach(Array(centers.enumerated()), id: \.offset) { pair in
                    if let image = images.element(at: pair.offset) {
                        let position = pair.element
                        let isDragging = activeDrag?.index == pair.offset
                        let translation = isDragging ? activeDrag?.translation ?? .zero : .zero
                        let baseView = Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cellSize, height: cellSize)
                            .clipped()
                            .position(position)
                            .offset(translation)
                            .scaleEffect(isDragging ? 1.06 : 1)
                            .zIndex(isDragging ? 1 : 0)
                        Group {
                            if isInteractive {
                                baseView.gesture(dragGesture(for: pair.offset, basePosition: position, centers: centers))
                            } else {
                                baseView
                            }
                        }
                    }
                }
                
                EmptyCellsOverlay(orientation: orientation, cellSize: cellSize, spacing: spacing)
                
                if let subject {
                    let placement = orientation.subjectPlacement(cellSize: cellSize, spacing: spacing, containerSize: size)
                    SubjectInteractiveImage(
                        subject: subject,
                        placement: placement,
                        cellSize: cellSize,
                        spacing: spacing,
                        transform: $subjectTransform,
                        isInteractive: isInteractive
                    )
                }
                if let target = dropTarget, let center = centers.element(at: target) {
                    Rectangle()
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [6, 6]))
                        .frame(width: cellSize, height: cellSize)
                        .position(center)
                }
            }
            .frame(width: size, height: size)
        }
    }
    
    private func nearestIndex(to point: CGPoint, centers: [CGPoint]) -> Int? {
        guard !centers.isEmpty else { return nil }
        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, center) in centers.enumerated() {
            let dx = point.x - center.x
            let dy = point.y - center.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }
    
    private func dragGesture(for index: Int, basePosition: CGPoint, centers: [CGPoint]) -> some Gesture {
        DragGesture()
            .onChanged { value in
                activeDrag = ActiveDrag(index: index, translation: value.translation)
                let newCenter = CGPoint(
                    x: basePosition.x + value.translation.width,
                    y: basePosition.y + value.translation.height
                )
                dropTarget = nearestIndex(to: newCenter, centers: centers)
            }
            .onEnded { value in
                let newCenter = CGPoint(
                    x: basePosition.x + value.translation.width,
                    y: basePosition.y + value.translation.height
                )
                if let target = nearestIndex(to: newCenter, centers: centers), target != index {
                    onReorder(index, target)
                }
                activeDrag = nil
                dropTarget = nil
            }
    }
}

private struct EmptyCellsOverlay: View {
    let orientation: LShapeOrientation
    let cellSize: CGFloat
    let spacing: CGFloat
    
    var body: some View {
        ForEach(orientation.emptyCells, id: \.self) { cell in
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .foregroundColor(Color.secondary.opacity(0.24))
                .frame(width: cellSize, height: cellSize)
                .position(orientation.position(for: cell, cellSize: cellSize, spacing: spacing))
        }
    }
}

private struct SubjectInteractiveImage: View {
    let subject: UIImage
    let placement: SubjectPlacement
    let cellSize: CGFloat
    let spacing: CGFloat
    @Binding var transform: SubjectTransform
    let isInteractive: Bool
    
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1
    
    private let minScale: CGFloat = 0.6
    private let maxScale: CGFloat = 2.6
    private let baseSizeMultiplier: CGFloat = 1.85
    private let offsetLimit: CGFloat = 1.4
    
    var body: some View {
        let currentScale = clampScale(transform.scale * pinchScale)
        let normalizedDrag = CGSize(
            width: dragTranslation.width / cellSize,
            height: dragTranslation.height / cellSize
        )
        let totalNormalizedOffset = CGSize(
            width: transform.offset.width + normalizedDrag.width,
            height: transform.offset.height + normalizedDrag.height
        )
        let clampedDisplayOffset = clampOffset(totalNormalizedOffset)
        let offset = CGSize(
            width: placement.offset.width + clampedDisplayOffset.width * cellSize,
            height: placement.offset.height + clampedDisplayOffset.height * cellSize
        )
        let size = cellSize * baseSizeMultiplier * currentScale
        let imageView = Image(uiImage: subject)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
            .position(placement.position)
            .offset(offset)
        
        if isInteractive {
            imageView
                .gesture(dragGesture.simultaneously(with: pinchGesture))
        } else {
            imageView
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                var newOffset = CGSize(
                    width: transform.offset.width + value.translation.width / cellSize,
                    height: transform.offset.height + value.translation.height / cellSize
                )
                newOffset = clampOffset(newOffset)
                transform.offset = newOffset
            }
    }
    
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = clampScale(transform.scale * value)
                transform.scale = newScale
                transform.offset = clampOffset(transform.offset)
            }
    }
    
    private func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }
    
    private func clampOffset(_ offset: CGSize) -> CGSize {
        let clampedX = min(max(offset.width, -offsetLimit), offsetLimit)
        let clampedY = min(max(offset.height, -offsetLimit), offsetLimit)
        return CGSize(width: clampedX, height: clampedY)
    }
}

private struct LayoutOrientationPicker: View {
    @Binding var selection: LShapeOrientation
    
    var body: some View {
        HStack(spacing: 14) {
            ForEach(LShapeOrientation.allCases) { orientation in
                Button {
                    selection = orientation
                } label: {
                    VStack(spacing: 8) {
                        LShapeIcon(orientation: orientation)
                            .frame(width: 60, height: 60)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selection == orientation ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selection == orientation ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        
                        Text(orientation.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selection == orientation ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LShapeIcon: View {
    let orientation: LShapeOrientation
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cellSize = size.width / 3
            let cells = orientation.filledCells
            let subjectCorner = orientation.subjectCornerCell
            
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
                
                ForEach(cells, id: \.self) { cell in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: cellSize * 0.7, height: cellSize * 0.7)
                        .position(orientation.iconPosition(for: cell, cellSize: cellSize))
                }
                
                if let subjectCorner {
                    let offset = orientation.iconSubjectOffset(for: cellSize)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: cellSize * 0.7, height: cellSize * 0.7)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: cellSize * 0.32, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .position(orientation.iconPosition(for: subjectCorner, cellSize: cellSize))
                        .offset(x: offset.width, y: offset.height)
                }
            }
        }
    }
}

private struct ProgressOverlay: View {
    var label: String?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                if let label {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct InstructionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon
                .font(.system(size: 14))
                .foregroundColor(Color.accentColor)
                .padding(.top, 2)
            configuration.title
        }
    }
}

private struct LowResolutionWarning: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("注意：部分小图分辨率较低")
                    .font(.system(size: 13, weight: .semibold))
                Text("导出效果可能出现模糊，建议更换更高清晰度的素材。")
                    .font(.system(size: 12))
            }
            .foregroundColor(.white)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)
        }
        .padding(14)
        .background(Color.orange.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 10)
    }
}

private struct MissingSubjectWarning: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("未检测到主体")
                    .font(.system(size: 13, weight: .semibold))
                Text("可以继续调整九宫格布局，或返回第一步重新选择主图。")
                    .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
        } icon: {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Models & Helpers

private struct SelectedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct CropTask: Identifiable {
    let id = UUID()
    let image: UIImage
    let replaceIndex: Int?
}

private struct CropState: Equatable {
    var scale: CGFloat = 1
    var normalizedOffset: CGSize = .zero
}

private enum LShapeOrientation: CaseIterable, Identifiable {
    case openingBottomRight
    case openingBottomLeft
    case openingTopRight
    case openingTopLeft
    
    var id: String { displayName }
    
    var displayName: String {
        switch self {
        case .openingBottomRight: return "L ↘"
        case .openingBottomLeft: return "L ↙"
        case .openingTopRight: return "L ↗"
        case .openingTopLeft: return "L ↖"
        }
    }
    
    var filledCells: [GridCell] {
        switch self {
        case .openingBottomRight:
            return [.init(0, 0), .init(0, 1), .init(0, 2), .init(1, 0), .init(2, 0)]
        case .openingBottomLeft:
            return [.init(0, 0), .init(0, 1), .init(0, 2), .init(1, 2), .init(2, 2)]
        case .openingTopRight:
            return [.init(2, 0), .init(2, 1), .init(2, 2), .init(1, 0), .init(0, 0)]
        case .openingTopLeft:
            return [.init(2, 0), .init(2, 1), .init(2, 2), .init(1, 2), .init(0, 2)]
        }
    }
    
    var emptyCells: [GridCell] {
        let filled = Set(filledCells)
        return GridCell.allCells.filter { !filled.contains($0) }
    }
    
    var subjectCornerCell: GridCell? {
        switch self {
        case .openingBottomRight: return .init(2, 2)
        case .openingBottomLeft: return .init(2, 0)
        case .openingTopRight: return .init(0, 2)
        case .openingTopLeft: return .init(0, 0)
        }
    }
    
    private var subjectOffsetMultiplier: CGSize {
        switch self {
        case .openingBottomRight: return CGSize(width: 0.28, height: 0.28)
        case .openingBottomLeft: return CGSize(width: -0.28, height: 0.28)
        case .openingTopRight: return CGSize(width: 0.28, height: -0.28)
        case .openingTopLeft: return CGSize(width: -0.28, height: -0.28)
        }
    }
    
    private var subjectAreaOrigin: GridCell {
        switch self {
        case .openingBottomRight:
            return GridCell(1, 1)
        case .openingBottomLeft:
            return GridCell(1, 0)
        case .openingTopRight:
            return GridCell(0, 1)
        case .openingTopLeft:
            return GridCell(0, 0)
        }
    }
    
    func cellSize(for containerSize: CGFloat, spacing: CGFloat) -> CGFloat {
        let totalSpacing = spacing * 2
        return (containerSize - totalSpacing) / 3
    }
    
    func cellOffsets(cellSize: CGFloat, spacing: CGFloat) -> [GridPlacement] {
        filledCells.map { cell in
            GridPlacement(cell: cell, orientation: self, cellSize: cellSize, spacing: spacing)
        }
    }
    
    func position(for cell: GridCell, cellSize: CGFloat, spacing: CGFloat) -> CGPoint {
        let offsetX = CGFloat(cell.column) * (cellSize + spacing) + cellSize / 2
        let offsetY = CGFloat(cell.row) * (cellSize + spacing) + cellSize / 2
        return CGPoint(x: offsetX, y: offsetY)
    }
    
    func subjectPlacement(cellSize: CGFloat, spacing: CGFloat, containerSize: CGFloat) -> SubjectPlacement {
        let originCell = subjectAreaOrigin
        let baseX = CGFloat(originCell.column) * (cellSize + spacing) + cellSize / 2
        let baseY = CGFloat(originCell.row) * (cellSize + spacing) + cellSize / 2
        let position = CGPoint(
            x: baseX + (cellSize + spacing) / 2,
            y: baseY + (cellSize + spacing) / 2
        )
        let offsetVector = CGSize(width: subjectOffsetMultiplier.width * cellSize, height: subjectOffsetMultiplier.height * cellSize)
        return SubjectPlacement(position: position, offset: offsetVector)
    }
    
    func iconPosition(for cell: GridCell, cellSize: CGFloat) -> CGPoint {
        let offsetX = CGFloat(cell.column) * cellSize + cellSize / 2
        let offsetY = CGFloat(cell.row) * cellSize + cellSize / 2
        return CGPoint(x: offsetX, y: offsetY)
    }
    
    func iconSubjectOffset(for cellSize: CGFloat) -> CGSize {
        CGSize(width: subjectOffsetMultiplier.width * cellSize * 0.4, height: subjectOffsetMultiplier.height * cellSize * 0.4)
    }
}

private struct GridCell: Hashable {
    let row: Int
    let column: Int
    
    init(_ row: Int, _ column: Int) {
        self.row = row
        self.column = column
    }
    
    static let allCells: [GridCell] = (0..<3).flatMap { row in
        (0..<3).map { column in
            GridCell(row, column)
        }
    }
}

private struct GridPlacement {
    let cell: GridCell
    let orientation: LShapeOrientation
    let cellSize: CGFloat
    let spacing: CGFloat
    
    func position() -> CGPoint {
        orientation.position(for: cell, cellSize: cellSize, spacing: spacing)
    }
}

private struct SubjectPlacement {
    let position: CGPoint
    let offset: CGSize
}

private struct SubjectTransform: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
}

private struct ActiveDrag {
    let index: Int
    var translation: CGSize
}

private struct CreativeNineGridError: Identifiable, Error {
    let id = UUID()
    let title: String
    let message: String?
}

// MARK: - Cropper View

private struct SquareCropperView: View {
    let image: UIImage
    @Binding var cropState: CropState
    
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureTranslation: CGSize = .zero
    @State private var baseScale: CGFloat = 1.0
    @State private var normalizedOffset: CGSize = .zero
    
    private let minimumScale: CGFloat = 1.0
    private let maximumScale: CGFloat = 4.5
    
    init(image: UIImage, cropState: Binding<CropState>) {
        self.image = image
        _cropState = cropState
        _baseScale = State(initialValue: max(minimumScale, cropState.wrappedValue.scale))
        _normalizedOffset = State(initialValue: cropState.wrappedValue.normalizedOffset)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let squareSize = min(geometry.size.width, geometry.size.height)
            let baseImageSize = calculateBaseImageSize(for: image, inside: squareSize)
            let appliedScale = clampScale(baseScale * gestureScale)
            let baseOffset = CGSize(
                width: normalizedOffset.width * squareSize,
                height: normalizedOffset.height * squareSize
            )
            let translatedOffset = CGSize(
                width: baseOffset.width + gestureTranslation.width,
                height: baseOffset.height + gestureTranslation.height
            )
            let clampedOffset = clampOffset(translatedOffset, imageSize: baseImageSize, squareSize: squareSize, scale: appliedScale)
            
            ZStack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: baseImageSize.width * appliedScale,
                               height: baseImageSize.height * appliedScale)
                        .offset(x: clampedOffset.width, y: clampedOffset.height)
                    
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        .frame(width: squareSize, height: squareSize)
                        .allowsHitTesting(false)
                    
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .blendMode(.normal)
                        .mask(
                            Rectangle()
                                .fill(
                                    RadialGradient(colors: [.white, .clear], center: .center, startRadius: squareSize / 1.95, endRadius: squareSize)
                                )
                        )
                        .allowsHitTesting(false)
                }
                .frame(width: squareSize, height: squareSize)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .gesture(
                simultaneousGestures(squareSize: squareSize, baseImageSize: baseImageSize)
            )
            .onChange(of: cropState) { _, newValue in
                baseScale = max(minimumScale, newValue.scale)
                normalizedOffset = newValue.normalizedOffset
            }
        }
    }
    
    private func simultaneousGestures(squareSize: CGFloat, baseImageSize: CGSize) -> some Gesture {
        let magnification = MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = clampScale(baseScale * value)
                baseScale = newScale
                let square = squareSize
                let clampedOffset = clampOffset(
                    CGSize(width: normalizedOffset.width * square, height: normalizedOffset.height * square),
                    imageSize: baseImageSize,
                    squareSize: square,
                    scale: newScale
                )
                normalizedOffset = CGSize(width: clampedOffset.width / square, height: clampedOffset.height / square)
                cropState.scale = newScale
                cropState.normalizedOffset = normalizedOffset
            }
        
        let drag = DragGesture()
            .updating($gestureTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let translated = CGSize(
                    width: normalizedOffset.width * squareSize + value.translation.width,
                    height: normalizedOffset.height * squareSize + value.translation.height
                )
                let clamped = clampOffset(translated, imageSize: baseImageSize, squareSize: squareSize, scale: baseScale)
                normalizedOffset = CGSize(width: clamped.width / squareSize, height: clamped.height / squareSize)
                cropState.normalizedOffset = normalizedOffset
            }
        
        return drag.simultaneously(with: magnification)
    }
    
    private func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }
    
    private func calculateBaseImageSize(for image: UIImage, inside square: CGFloat) -> CGSize {
        guard square > 0 else { return .zero }
        let aspect = image.size.width / image.size.height
        if aspect > 1 {
            return CGSize(width: square * aspect, height: square)
        } else {
            return CGSize(width: square, height: square / aspect)
        }
    }
    
    private func clampOffset(_ offset: CGSize, imageSize: CGSize, squareSize: CGFloat, scale: CGFloat) -> CGSize {
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let horizontalMax = max((width - squareSize) / 2, 0)
        let verticalMax = max((height - squareSize) / 2, 0)
        let clampedX = min(max(offset.width, -horizontalMax), horizontalMax)
        let clampedY = min(max(offset.height, -verticalMax), verticalMax)
        return CGSize(width: clampedX, height: clampedY)
    }
}

// MARK: - Rendering Helpers

private final class CropRenderer {
    private let outputSize: CGFloat = 1080
    
    func cropSquare(image: UIImage, state: CropState) -> UIImage? {
        guard image.size.width > 1, image.size.height > 1 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: CGSize(width: outputSize, height: outputSize)))
            
            let baseSize = baseImageSize(for: image, inside: outputSize)
            let appliedScale = max(state.scale, 1)
            let drawSize = CGSize(width: baseSize.width * appliedScale, height: baseSize.height * appliedScale)
            let offset = CGSize(
                width: state.normalizedOffset.width * outputSize,
                height: state.normalizedOffset.height * outputSize
            )
            let origin = CGPoint(
                x: (outputSize - drawSize.width) / 2 + offset.width,
                y: (outputSize - drawSize.height) / 2 + offset.height
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
    
    private func baseImageSize(for image: UIImage, inside square: CGFloat) -> CGSize {
        let aspect = image.size.width / image.size.height
        if aspect > 1 {
            return CGSize(width: square * aspect, height: square)
        } else {
            return CGSize(width: square, height: square / aspect)
        }
    }
}

private final class NineGridRenderer {
    private let baseSize: CGFloat = 2048
    private let bleedRatio: CGFloat = 0.10
    
    func renderNineGrid(
        smallImages: [UIImage],
        subject: UIImage?,
        orientation: LShapeOrientation,
        spacing: CGFloat,
        subjectTransform: SubjectTransform
    ) -> UIImage? {
        let bleed = baseSize * bleedRatio
        let canvasSize = CGSize(width: baseSize + bleed * 2, height: baseSize + bleed * 2)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            let canvas = CGRect(origin: .zero, size: canvasSize)
            UIColor.white.setFill()
            context.fill(canvas)
            
            let totalSpacing = spacing * 2
            let cellSize = (baseSize - totalSpacing) / 3
            let offset = CGPoint(x: bleed, y: bleed)
            
            for (index, cell) in orientation.filledCells.enumerated() {
                guard let image = smallImages.element(at: index) else { continue }
                let origin = CGPoint(
                    x: offset.x + CGFloat(cell.column) * (cellSize + spacing),
                    y: offset.y + CGFloat(cell.row) * (cellSize + spacing)
                )
                let rect = CGRect(origin: origin, size: CGSize(width: cellSize, height: cellSize))
                image.draw(in: rect)
            }
            
            if let subject {
                let placement = orientation.subjectPlacement(cellSize: cellSize, spacing: spacing, containerSize: baseSize)
                let trimmedSubject = subject.trimmedToOpaqueBounds()
                let subjectScale = max(trimmedSubject.size.width, trimmedSubject.size.height)
                let desiredSize = cellSize * 1.9 * subjectTransform.scale
                let scale = subjectScale > 0 ? desiredSize / subjectScale : 1
                let subjectSize = CGSize(width: trimmedSubject.size.width * scale, height: trimmedSubject.size.height * scale)
                let transformOffset = CGSize(
                    width: subjectTransform.offset.width * cellSize,
                    height: subjectTransform.offset.height * cellSize
                )
                let origin = CGPoint(
                    x: offset.x + placement.position.x - subjectSize.width / 2 + placement.offset.width + transformOffset.width,
                    y: offset.y + placement.position.y - subjectSize.height / 2 + placement.offset.height + transformOffset.height
                )
                context.cgContext.saveGState()
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 18), blur: 28, color: UIColor.black.withAlphaComponent(0.24).cgColor)
                trimmedSubject.draw(in: CGRect(origin: origin, size: subjectSize))
                context.cgContext.restoreGState()
            }
        }
    }
}

private final class PersonSegmenter {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    func generateSubjectCutout(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw CreativeNineGridError(title: "无效图片", message: "主图格式不受支持。")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let orientation = CGImagePropertyOrientation(image.imageOrientation)
                    let request = VNGeneratePersonSegmentationRequest()
                    request.qualityLevel = .accurate
                    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
                    
                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                    try handler.perform([request])
                    
                    guard let result = request.results?.first else {
                        throw CreativeNineGridError(title: "抠图失败", message: "未检测到人物主体。")
                    }
                    
                    let maskImage = CIImage(cvPixelBuffer: result.pixelBuffer).oriented(orientation)
                    let originalImage = CIImage(cgImage: cgImage)
                    
                    let scaleX = originalImage.extent.width / maskImage.extent.width
                    let scaleY = originalImage.extent.height / maskImage.extent.height
                    let resizedMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                    
                    let background = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: originalImage.extent)
                    
                    let composited = originalImage.applyingFilter("CIBlendWithMask", parameters: [
                        kCIInputBackgroundImageKey: background,
                        kCIInputMaskImageKey: resizedMask
                    ])
                    
                    guard let compositedCG = self.ciContext.createCGImage(composited, from: originalImage.extent) else {
                        throw CreativeNineGridError(title: "抠图失败", message: "生成主体图像失败。")
                    }
                    
                    let cutout = UIImage(cgImage: compositedCG, scale: image.scale, orientation: image.imageOrientation)
                    continuation.resume(returning: cutout)
                } catch {
                    if let gridError = error as? CreativeNineGridError {
                        continuation.resume(throwing: gridError)
                    } else {
                        continuation.resume(throwing: CreativeNineGridError(
                            title: "抠图失败",
                            message: "自动识别主体时出现问题，请尝试其他照片。"
                        ))
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

private extension PhotosPickerItem {
    func loadUIImage() async -> UIImage? {
        if let data = try? await self.loadTransferable(type: Data.self), let image = UIImage(data: data) {
            return image.fixOrientation()
        }
        return nil
    }
}

private extension UIImage {
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
    
    func trimmedToOpaqueBounds() -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let totalBytes = height * bytesPerRow
        guard let data = malloc(totalBytes) else { return self }
        defer { free(data) }
        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let buffer = data.bindMemory(to: UInt8.self, capacity: totalBytes)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = y * bytesPerRow + x * bytesPerPixel
                let alpha = buffer[index + 3]
                if alpha > 16 { // threshold to avoid noise
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        if minX > maxX || minY > maxY {
            return self
        }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cgImage.cropping(to: rect) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

private extension Array {
    func element(at index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension PHAuthorizationStatus {
    var canAddToLibrary: Bool {
        switch self {
        case .authorized, .limited: return true
        default: return false
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

#Preview {
    NavigationStack {
        CreativeNineGridView()
    }
}
