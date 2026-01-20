//
//  TextToImageView.swift
//  lovpic
//
//  文生图功能视图
//

import SwiftUI

struct TextToImageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TextToImageViewModel()
    @FocusState private var isPromptFocused: Bool
    
    private let backgroundGradient = [
        Color(red: 0.07, green: 0.07, blue: 0.09),
        Color(red: 0.12, green: 0.11, blue: 0.15)
    ]
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(colors: backgroundGradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 提示词输入区
                    PromptInputSection(
                        prompt: $viewModel.prompt,
                        isFocused: $isPromptFocused
                    )
                    
                    // 模型选择
                    if !viewModel.configs.isEmpty {
                        ModelSelectionSection(
                            configs: viewModel.configs,
                            selectedConfig: $viewModel.selectedConfig
                        )
                    }
                    
                    // 参数设置
                    if viewModel.selectedConfig != nil {
                        ParameterSection(viewModel: viewModel)
                    }
                    
                    // 生成按钮
                    GenerateButton(
                        isLoading: viewModel.isGenerating,
                        isDisabled: viewModel.prompt.isEmpty || viewModel.selectedConfig == nil,
                        action: { Task { await viewModel.generate() } }
                    )
                    
                    // 生成结果
                    if let imageUrl = viewModel.generatedImageUrl {
                        GeneratedImageSection(imageUrl: imageUrl)
                    }
                    
                    // 错误提示
                    if let error = viewModel.error {
                        ErrorBanner(message: error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("文生图")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await viewModel.loadConfigs()
        }
        .onTapGesture {
            isPromptFocused = false
        }
    }
}

// MARK: - ViewModel

@MainActor
final class TextToImageViewModel: ObservableObject {
    @Published var prompt = ""
    @Published var configs: [AIProviderConfig] = []
    @Published var selectedConfig: AIProviderConfig?
    @Published var isGenerating = false
    @Published var generatedImageUrl: String?
    @Published var error: String?
    
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
        configs = AIImageService.shared.configs
        if selectedConfig == nil {
            selectedConfig = configs.first
        }
    }
    
    func generate() async {
        guard let config = selectedConfig, !prompt.isEmpty else { return }
        
        isGenerating = true
        error = nil
        generatedImageUrl = nil
        
        do {
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
            
            let urls = try await AIImageService.shared.generateImage(
                configId: config.id,
                prompt: prompt,
                params: params
            )
            
            generatedImageUrl = urls.first
        } catch {
            self.error = error.localizedDescription
        }
        
        isGenerating = false
    }
}

// MARK: - 提示词输入区

private struct PromptInputSection: View {
    @Binding var prompt: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("描述你想要的图片", systemImage: "text.bubble.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFocused.wrappedValue ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if prompt.isEmpty {
                    Text("例如：一只金色的猫咪趴在阳光下的草地上，毛发柔软蓬松，眼神慵懒...")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(16)
                }
                
                TextEditor(text: $prompt)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .focused(isFocused)
            }
            .frame(height: 140)
            
            HStack {
                Spacer()
                Text("\(prompt.count)/300")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - 模型选择

private struct ModelSelectionSection: View {
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
                        ModelCard(
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

private struct ModelCard: View {
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
                        .foregroundColor(.cyan)
                }
            }
            .padding(14)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 参数设置

private struct ParameterSection: View {
    @ObservedObject var viewModel: TextToImageViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("参数设置", systemImage: "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                if viewModel.selectedConfig?.provider == .kie {
                    ParameterPicker(
                        title: "宽高比",
                        selection: $viewModel.aspectRatio,
                        options: viewModel.aspectRatioOptions
                    )
                    
                    ParameterPicker(
                        title: "质量",
                        selection: $viewModel.quality,
                        options: viewModel.qualityOptions,
                        labels: ["基础 2K", "高清 4K"]
                    )
                }
                
                if viewModel.selectedConfig?.provider == .seedream {
                    ParameterPicker(
                        title: "分辨率",
                        selection: $viewModel.size,
                        options: viewModel.sizeOptions
                    )
                    
                    Toggle(isOn: $viewModel.watermark) {
                        Text("添加水印")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .tint(.cyan)
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

private struct ParameterPicker: View {
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
                                    .fill(selection == option ? Color.cyan : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 生成按钮

private struct GenerateButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(isLoading ? "生成中..." : "开始生成")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: isDisabled ? [Color.gray.opacity(0.3)] : [Color.cyan, Color.cyan.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isDisabled ? .clear : Color.cyan.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 生成结果

private struct GeneratedImageSection: View {
    let imageUrl: String
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("生成结果", systemImage: "photo.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.cyan)
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

private struct ErrorBanner: View {
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

// MARK: - 按钮样式

private struct ScaleButtonStyle: ButtonStyle {
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
        TextToImageView()
    }
}
