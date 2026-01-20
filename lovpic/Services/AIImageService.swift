//
//  AIImageService.swift
//  lovpic
//
//  AI 图像生成服务 - 支持 kie、ModelScope、Seedream 三个提供商
//

import Foundation
import Supabase

// MARK: - Models

/// AI 提供商类型
enum AIProvider: String, Codable, CaseIterable {
    case kie = "kie"
    case modelscope = "modelscope"
    case seedream = "seedream"
    
    var displayName: String {
        switch self {
        case .kie: return "Kie AI"
        case .modelscope: return "ModelScope"
        case .seedream: return "Seedream"
        }
    }
}

/// 模型类型
enum AIModelType: String, Codable {
    case textToImage = "text-to-image"
    case imageEdit = "image-edit"
    case removeBackground = "remove-background"
    case imageGeneration = "image-generation"
    
    var displayName: String {
        switch self {
        case .textToImage: return "文生图"
        case .imageEdit: return "图片编辑"
        case .removeBackground: return "背景移除"
        case .imageGeneration: return "图片生成"
        }
    }
    
    /// 是否需要输入图片
    var requiresImage: Bool {
        switch self {
        case .textToImage: return false
        case .imageEdit, .removeBackground, .imageGeneration: return true
        }
    }
}

/// AI 提供商配置
struct AIProviderConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let provider: AIProvider
    let baseUrl: String
    let modelId: String
    let modelType: AIModelType?
    let isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, provider
        case baseUrl = "base_url"
        case modelId = "model_id"
        case modelType = "model_type"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
    
    /// 根据 model_id 推断模型类型
    var effectiveModelType: AIModelType {
        if let modelType = modelType {
            return modelType
        }
        // 根据 model_id 推断
        if modelId.contains("remove-background") {
            return .removeBackground
        } else if modelId.contains("edit") {
            return .imageEdit
        } else if modelId == "nano-banana-pro" {
            return .imageGeneration
        }
        return .textToImage
    }
}

/// 图像生成请求
struct ImageGenerationRequest: Encodable {
    let configId: String
    let prompt: String?
    let imageUrl: String?
    let imageUrls: [String]?
    let params: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case configId = "config_id"
        case prompt
        case imageUrl = "image_url"
        case imageUrls = "image_urls"
        case params
    }
}

/// 图像生成响应
struct ImageGenerationResponse: Decodable {
    let success: Bool?
    let urls: [String]?
    let taskId: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, urls, error
        case taskId = "taskId"
    }
}

/// 通用 Codable 包装器
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Service

/// AI 图像生成服务
@MainActor
final class AIImageService: ObservableObject {
    static let shared = AIImageService()
    
    @Published private(set) var configs: [AIProviderConfig] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    
    private init() {}
    
    /// 获取所有可用的 AI 配置
    func fetchConfigs() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: [AIProviderConfig] = try await SupabaseConfig.client
                .from("ai_provider_configs")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value
            configs = response
        } catch {
            self.error = "获取配置失败: \(error.localizedDescription)"
        }
    }
    
    /// 文生图 - 仅需要 prompt
    /// - Parameters:
    ///   - configId: 配置 ID
    ///   - prompt: 提示词
    ///   - params: 额外参数（aspect_ratio, quality, resolution 等）
    /// - Returns: 生成的图片 URL 数组
    func generateImage(
        configId: UUID,
        prompt: String,
        params: [String: Any]? = nil
    ) async throws -> [String] {
        let requestParams = params?.mapValues { AnyCodable($0) }
        
        let response: ImageGenerationResponse = try await SupabaseConfig.client.functions
            .invoke(
                "generate-image",
                options: FunctionInvokeOptions(
                    body: ImageGenerationRequest(
                        configId: configId.uuidString,
                        prompt: prompt,
                        imageUrl: nil,
                        imageUrls: nil,
                        params: requestParams
                    )
                )
            )
        
        return try extractUrls(from: response)
    }
    
    /// 图片编辑 - 需要 prompt 和图片
    /// - Parameters:
    ///   - configId: 配置 ID
    ///   - prompt: 编辑指令
    ///   - imageUrls: 输入图片 URL 数组
    ///   - params: 额外参数
    /// - Returns: 编辑后的图片 URL 数组
    func editImage(
        configId: UUID,
        prompt: String,
        imageUrls: [String],
        params: [String: Any]? = nil
    ) async throws -> [String] {
        let requestParams = params?.mapValues { AnyCodable($0) }
        
        let response: ImageGenerationResponse = try await SupabaseConfig.client.functions
            .invoke(
                "generate-image",
                options: FunctionInvokeOptions(
                    body: ImageGenerationRequest(
                        configId: configId.uuidString,
                        prompt: prompt,
                        imageUrl: nil,
                        imageUrls: imageUrls,
                        params: requestParams
                    )
                )
            )
        
        return try extractUrls(from: response)
    }
    
    /// 背景移除 - 仅需要图片
    /// - Parameters:
    ///   - configId: 配置 ID
    ///   - imageUrl: 输入图片 URL
    /// - Returns: 移除背景后的图片 URL 数组
    func removeBackground(
        configId: UUID,
        imageUrl: String
    ) async throws -> [String] {
        let response: ImageGenerationResponse = try await SupabaseConfig.client.functions
            .invoke(
                "generate-image",
                options: FunctionInvokeOptions(
                    body: ImageGenerationRequest(
                        configId: configId.uuidString,
                        prompt: nil,
                        imageUrl: imageUrl,
                        imageUrls: nil,
                        params: nil
                    )
                )
            )
        
        return try extractUrls(from: response)
    }
    
    /// Nano Banana Pro - 支持 prompt 和可选图片输入
    /// - Parameters:
    ///   - configId: 配置 ID
    ///   - prompt: 提示词
    ///   - imageUrls: 可选的参考图片 URL 数组（最多8张）
    ///   - params: 额外参数（aspect_ratio, resolution, output_format）
    /// - Returns: 生成的图片 URL 数组
    func generateWithNanoBananaPro(
        configId: UUID,
        prompt: String,
        imageUrls: [String]? = nil,
        params: [String: Any]? = nil
    ) async throws -> [String] {
        let requestParams = params?.mapValues { AnyCodable($0) }
        
        let response: ImageGenerationResponse = try await SupabaseConfig.client.functions
            .invoke(
                "generate-image",
                options: FunctionInvokeOptions(
                    body: ImageGenerationRequest(
                        configId: configId.uuidString,
                        prompt: prompt,
                        imageUrl: nil,
                        imageUrls: imageUrls,
                        params: requestParams
                    )
                )
            )
        
        return try extractUrls(from: response)
    }
    
    /// 根据提供商获取配置
    func configs(for provider: AIProvider) -> [AIProviderConfig] {
        configs.filter { $0.provider == provider }
    }
    
    /// 根据模型类型获取配置
    func configs(for modelType: AIModelType) -> [AIProviderConfig] {
        configs.filter { $0.effectiveModelType == modelType }
    }
    
    // MARK: - Private
    
    private func extractUrls(from response: ImageGenerationResponse) throws -> [String] {
        if let error = response.error {
            throw AIImageError.serverError(error)
        }
        
        guard let urls = response.urls, !urls.isEmpty else {
            throw AIImageError.noImageGenerated
        }
        
        return urls
    }
}

// MARK: - Errors

enum AIImageError: LocalizedError {
    case serverError(String)
    case noImageGenerated
    case invalidConfig
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .noImageGenerated:
            return "未能生成图片"
        case .invalidConfig:
            return "无效的配置"
        }
    }
}
