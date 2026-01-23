//
//  ImageEditView.swift
//  lovpic
//
//  AI 图片编辑视图 - 用户选择图片并输入提示词进行编辑
//

import SwiftUI
import PhotosUI

struct ImageEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ImageEditViewModel()
    
    private let backgroundGradient = [
        Color(red: 0.07, green: 0.07, blue: 0.09),
        Color(red: 0.12, green: 0.11, blue: 0.15)
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(colors: backgroundGradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 图片选择区（含浮动输入框）
                    ImagePickerSection(
                        selectedImage: viewModel.selectedImage,
                        prompt: $viewModel.prompt,
                        isGenerating: viewModel.isGenerating,
                        canGenerate: viewModel.selectedConfig != nil,
                        onPickImage: { viewModel.showImagePicker = true },
                        onGenerate: { Task { await viewModel.editImage() } }
                    )
                    
                    // 模型选择
                    if !viewModel.configs.isEmpty {
                        EditModelSelectionSection(
                            configs: viewModel.configs,
                            selectedConfig: $viewModel.selectedConfig
                        )
                    }
                    
                    // 参数设置
                    if viewModel.selectedConfig != nil {
                        EditParameterSection(viewModel: viewModel)
                    }
                    
                    // 编辑结果
                    if let imageUrl = viewModel.editedImageUrl {
                        EditedImageSection(imageUrl: imageUrl)
                    }
                    
                    // 错误提示
                    if let error = viewModel.error {
                        EditErrorBanner(message: error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("图片编辑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(image: $viewModel.selectedImage)
        }
        .task {
            await viewModel.loadConfigs()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ImageEditViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var prompt = ""
    @Published var configs: [AIProviderConfig] = []
    @Published var selectedConfig: AIProviderConfig?
    @Published var isGenerating = false
    @Published var editedImageUrl: String?
    @Published var error: String?
    @Published var showImagePicker = false
    
    // 参数
    @Published var aspectRatio = "1:1"
    @Published var quality = "basic"
    @Published var size = "2K"
    @Published var watermark = false
    
    let aspectRatioOptions = ["1:1", "4:3", "3:4", "16:9", "9:16", "2:3", "3:2"]
    let qualityOptions = ["basic", "high"]
    let sizeOptions = ["2K", "4K"]
    
    func loadConfigs() async {
        await AIImageService.shared.fetchConfigs()
        // 使用新的板块过滤方法获取图片编辑模型
        configs = AIImageService.shared.configs(for: .imageEdit)
        
        if selectedConfig == nil {
            selectedConfig = configs.first
        }
    }
    
    func editImage() async {
        guard let config = selectedConfig,
              let image = selectedImage,
              !prompt.isEmpty else { return }
        
        isGenerating = true
        error = nil
        editedImageUrl = nil
        
        do {
            // 上传图片获取 URL
            let imageUrl = try await uploadImage(image)
            
            var params: [String: Any] = [:]
            
            switch config.provider {
            case .kie:
                params["aspect_ratio"] = aspectRatio
                params["quality"] = quality
            case .seedream:
                params["size"] = size
                params["watermark"] = watermark
            case .modelscope:
                break
            }
            
            let urls = try await AIImageService.shared.editImage(
                configId: config.id,
                prompt: prompt,
                imageUrls: [imageUrl],
                params: params
            )
            
            editedImageUrl = urls.first
        } catch {
            self.error = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    private func uploadImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageEditError.imageConversionFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "edit-images/\(fileName)"
        
        try await SupabaseConfig.client.storage
            .from("images")
            .upload(filePath, data: imageData, options: .init(contentType: "image/jpeg"))
        
        let publicUrl = try SupabaseConfig.client.storage
            .from("images")
            .getPublicURL(path: filePath)
        
        return publicUrl.absoluteString
    }
}

enum ImageEditError: LocalizedError {
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "图片转换失败"
        }
    }
}

// MARK: - 图片选择区（含浮动输入框）

private struct ImagePickerSection: View {
    let selectedImage: UIImage?
    @Binding var prompt: String
    let isGenerating: Bool
    let canGenerate: Bool
    let onPickImage: () -> Void
    let onGenerate: () -> Void
    
    @State private var isInputExpanded = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("选择要编辑的图片", systemImage: "photo.on.rectangle.angled")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            ZStack(alignment: .bottomTrailing) {
                // 图片或占位区域
                Button(action: onPickImage) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.cyan.opacity(0.7))
                                
                                Text("点击选择图片")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .frame(height: 180)
                    }
                }
                .buttonStyle(EditScaleButtonStyle())
                
                // 浮动输入区域（仅在选择图片后显示）
                if selectedImage != nil {
                    FloatingPromptInput(
                        prompt: $prompt,
                        isExpanded: $isInputExpanded,
                        isFocused: $isTextFieldFocused,
                        isGenerating: isGenerating,
                        canGenerate: canGenerate && !prompt.isEmpty,
                        onGenerate: onGenerate
                    )
                    .padding(12)
                }
            }
        }
    }
}

// MARK: - 浮动输入框

private struct FloatingPromptInput: View {
    @Binding var prompt: String
    @Binding var isExpanded: Bool
    var isFocused: FocusState<Bool>.Binding
    let isGenerating: Bool
    let canGenerate: Bool
    let onGenerate: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isExpanded {
                // 展开状态：输入框 + 确认按钮
                HStack(alignment: .bottom, spacing: 8) {
                    // 自适应高度的输入框（含关闭按钮）
                    HStack(alignment: .bottom, spacing: 6) {
                        TextField("输入你想要的编辑效果", text: $prompt, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .lineLimit(1...6)
                            .focused(isFocused)
                        
                        // 收起按钮
                        Button(action: {
                            isFocused.wrappedValue = false
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.bottom, 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    
                    // 确认按钮
                    Button(action: {
                        isFocused.wrappedValue = false
                        onGenerate()
                    }) {
                        ZStack {
                            Circle()
                                .fill(canGenerate ? Color.orange : Color.gray.opacity(0.4))
                                .frame(width: 40, height: 40)
                            
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(canGenerate ? .white : .white.opacity(0.4))
                            }
                        }
                    }
                    .disabled(!canGenerate || isGenerating)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity)
                ))
            } else {
                // 收起状态：仅显示图标
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused.wrappedValue = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "pencil.tip.crop.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                .buttonStyle(EditScaleButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isExpanded)
    }
}

// MARK: - 模型选择

private struct EditModelSelectionSection: View {
    let configs: [AIProviderConfig]
    @Binding var selectedConfig: AIProviderConfig?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("选择模型", systemImage: "cpu.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(configs) { config in
                        EditModelCard(
                            config: config,
                            isSelected: selectedConfig?.id == config.id,
                            onSelect: { selectedConfig = config }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}

private struct EditModelCard: View {
    let config: AIProviderConfig
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(config.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(14)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.orange.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(EditScaleButtonStyle())
    }
}

// MARK: - 参数设置

private struct EditParameterSection: View {
    @ObservedObject var viewModel: ImageEditViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("参数设置", systemImage: "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                if viewModel.selectedConfig?.provider == .kie {
                    EditParameterPicker(
                        title: "宽高比",
                        selection: $viewModel.aspectRatio,
                        options: viewModel.aspectRatioOptions
                    )
                    
                    EditParameterPicker(
                        title: "质量",
                        selection: $viewModel.quality,
                        options: viewModel.qualityOptions,
                        labels: ["基础 2K", "高清 4K"]
                    )
                }
                
                if viewModel.selectedConfig?.provider == .seedream {
                    EditParameterPicker(
                        title: "分辨率",
                        selection: $viewModel.size,
                        options: viewModel.sizeOptions
                    )
                    
                    Toggle(isOn: $viewModel.watermark) {
                        Text("添加水印")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .tint(.orange)
                }
                
                if viewModel.selectedConfig?.provider == .modelscope {
                    Text("该模型暂无可调参数")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
}

private struct EditParameterPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    var labels: [String]? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    let label = labels?[safe: index] ?? option
                    Button(action: { selection = option }) {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selection == option ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selection == option ? Color.orange : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 编辑结果

private struct EditedImageSection: View {
    let imageUrl: String
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("编辑结果", systemImage: "photo.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 300)
                        .overlay(ProgressView())
                    
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                    
                case .failure:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                Text("图片加载失败")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        )
                    
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - 错误提示

private struct EditErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 图片选择器

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

// MARK: - 按钮样式

private struct EditScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ImageEditView()
    }
}
