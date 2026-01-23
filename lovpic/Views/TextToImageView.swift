//
//  TextToImageView.swift
//  lovpic
//
//  文生图功能视图 - Soft UI Evolution 主题
//

import SwiftUI

struct TextToImageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TextToImageViewModel()
    @FocusState private var isPromptFocused: Bool
    
    // Soft UI Evolution 配色
    private let backgroundColor = Color(hex: "F5F5F7")
    private let cardColor = Color.white
    private let primaryColor = Color(hex: "3B82F6")
    private let accentColor = Color(hex: "F97316")
    private let textColor = Color(hex: "1D1D1F")
    private let secondaryTextColor = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    
    var body: some View {
        ZStack {
            // 背景
            backgroundColor.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 提示词输入区
                    PromptInputSection(
                        prompt: $viewModel.prompt,
                        isFocused: $isPromptFocused,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                        cardColor: cardColor,
                        borderColor: borderColor
                    )
                    
                    // 模型选择
                    if !viewModel.configs.isEmpty {
                        ModelSelectionSection(
                            configs: viewModel.configs,
                            selectedConfig: $viewModel.selectedConfig,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardColor: cardColor,
                            borderColor: borderColor
                        )
                    }
                    
                    // 参数设置
                    if viewModel.selectedConfig != nil {
                        ParameterSection(
                            viewModel: viewModel,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            cardColor: cardColor,
                            borderColor: borderColor
                        )
                    }
                    
                    // 生成按钮
                    GenerateButton(
                        isLoading: viewModel.isGenerating,
                        isDisabled: viewModel.prompt.isEmpty || viewModel.selectedConfig == nil,
                        primaryColor: primaryColor,
                        accentColor: accentColor,
                        action: { Task { await viewModel.generate() } }
                    )
                    
                    // 生成结果
                    if let imageUrl = viewModel.generatedImageUrl {
                        GeneratedImageSection(
                            imageUrl: imageUrl,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardColor: cardColor
                        )
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
        .toolbarBackground(backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        // 使用新的板块过滤方法获取文生图模型
        configs = AIImageService.shared.configs(for: .textToImage)
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
    let primaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let cardColor: Color
    let borderColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("描述你想要的图片", systemImage: "text.bubble.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardColor)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFocused.wrappedValue ? primaryColor : borderColor, lineWidth: isFocused.wrappedValue ? 2 : 1)
                    )
                
                if prompt.isEmpty {
                    Text("例如：一只金色的猫咪趴在阳光下的草地上，毛发柔软蓬松，眼神慵懒...")
                        .font(.system(size: 15))
                        .foregroundColor(secondaryTextColor.opacity(0.6))
                        .padding(16)
                }
                
                TextEditor(text: $prompt)
                    .font(.system(size: 15))
                    .foregroundColor(textColor)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .focused(isFocused)
            }
            .frame(height: 140)
            
            HStack {
                Spacer()
                Text("\(prompt.count)/300")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
        }
    }
}

// MARK: - 模型选择

private struct ModelSelectionSection: View {
    let configs: [AIProviderConfig]
    @Binding var selectedConfig: AIProviderConfig?
    let primaryColor: Color
    let textColor: Color
    let cardColor: Color
    let borderColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("选择模型", systemImage: "cpu.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(configs) { config in
                        ModelCard(
                            config: config,
                            isSelected: selectedConfig?.id == config.id,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
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
    let primaryColor: Color
    let textColor: Color
    let cardColor: Color
    let borderColor: Color
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(config.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : textColor)
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(14)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? primaryColor : cardColor)
                    .shadow(color: isSelected ? primaryColor.opacity(0.3) : Color.black.opacity(0.06), radius: isSelected ? 8 : 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(SoftButtonStyle())
    }
}

// MARK: - 参数设置

private struct ParameterSection: View {
    @ObservedObject var viewModel: TextToImageViewModel
    let primaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let cardColor: Color
    let borderColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("参数设置", systemImage: "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)
            
            VStack(spacing: 16) {
                if viewModel.selectedConfig?.provider == .kie {
                    ParameterPicker(
                        title: "宽高比",
                        selection: $viewModel.aspectRatio,
                        options: viewModel.aspectRatioOptions,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor
                    )
                    
                    ParameterPicker(
                        title: "质量",
                        selection: $viewModel.quality,
                        options: viewModel.qualityOptions,
                        labels: ["基础 2K", "高清 4K"],
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor
                    )
                }
                
                if viewModel.selectedConfig?.provider == .seedream {
                    ParameterPicker(
                        title: "分辨率",
                        selection: $viewModel.size,
                        options: viewModel.sizeOptions,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor
                    )
                    
                    Toggle(isOn: $viewModel.watermark) {
                        Text("添加水印")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor)
                    }
                    .tint(primaryColor)
                }
                
                if viewModel.selectedConfig?.provider == .modelscope {
                    Text("该模型暂无可调参数")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardColor)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
    }
}

private struct ParameterPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    var labels: [String]? = nil
    let primaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    let label = labels?[safe: index] ?? option
                    Button(action: { selection = option }) {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selection == option ? .white : secondaryTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selection == option ? primaryColor : Color(hex: "F3F4F6"))
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
    let primaryColor: Color
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(isLoading ? "生成中..." : "开始生成")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDisabled ? Color.gray.opacity(0.4) : accentColor)
                    .shadow(color: isDisabled ? .clear : accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
            )
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(SoftButtonStyle())
    }
}

// MARK: - 生成结果

private struct GeneratedImageSection: View {
    let imageUrl: String
    let primaryColor: Color
    let textColor: Color
    let cardColor: Color
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("生成结果", systemImage: "photo.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                
                Spacer()
                
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryColor)
                }
            }
            
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardColor)
                        .frame(height: 300)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                        .overlay(ProgressView().tint(primaryColor))
                    
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                    
                case .failure:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardColor)
                        .frame(height: 200)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                Text("图片加载失败")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(Color(hex: "6B7280"))
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
                .foregroundColor(Color(hex: "EF4444"))
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "1D1D1F"))
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "FEF2F2"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "FECACA"), lineWidth: 1)
                )
        )
    }
}

// MARK: - Soft UI 按钮样式

private struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
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
