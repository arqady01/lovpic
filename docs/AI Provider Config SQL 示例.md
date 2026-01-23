# AI Provider Config SQL 示例

## 设计理念

配置表只存储**服务端必需的配置信息**（API 凭证、端点等），而**用户可控参数**（prompt、图片比例、质量等）由 App 在请求时动态传递。

### 服务端配置 vs 客户端参数

| 类型 | 存储位置 | 示例 |
|------|----------|------|
| 服务端配置 | `ai_provider_configs` 表 | API Key、Base URL、Model ID、Input Type、Category |
| 客户端参数 | App 请求体 | prompt、aspect_ratio、quality、size、image_url |

### 模型分类设计

为了让不同功能板块只显示兼容的模型，采用 `input_type` + `category` 双字段设计：

| 字段 | 职责 | 说明 |
|------|------|------|
| input_type | 输入要求（技术约束） | 决定模型能否出现在某个板块 |
| category | 功能场景（业务分组） | 控制 UI 上的分组展示 |

---

## 创建表

在 Supabase Dashboard 的 SQL Editor 中执行：

```sql
CREATE TABLE ai_provider_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    provider TEXT NOT NULL CHECK (provider IN ('kie', 'modelscope', 'seedream')),
    base_url TEXT NOT NULL,
    api_key TEXT NOT NULL,
    model_id TEXT NOT NULL,
    input_type TEXT NOT NULL DEFAULT 'text-only' CHECK (input_type IN ('text-only', 'image-required', 'image-optional')),
    category TEXT NOT NULL DEFAULT 'general',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 添加注释
COMMENT ON TABLE ai_provider_configs IS 'AI 图像生成模型提供商配置表';
COMMENT ON COLUMN ai_provider_configs.provider IS '提供商: kie, modelscope, seedream';
COMMENT ON COLUMN ai_provider_configs.input_type IS '输入类型: text-only(仅文字), image-required(必须图片), image-optional(图片可选)';
COMMENT ON COLUMN ai_provider_configs.category IS '功能分类: general(通用), logo(Logo生成), avatar(头像), background-removal(背景移除) 等';

-- 创建索引加速查询
CREATE INDEX idx_provider_active ON ai_provider_configs(provider, is_active);
CREATE INDEX idx_input_type ON ai_provider_configs(input_type);
CREATE INDEX idx_category ON ai_provider_configs(category);
CREATE INDEX idx_category_input_type ON ai_provider_configs(category, input_type, is_active);

-- 启用 RLS
ALTER TABLE ai_provider_configs ENABLE ROW LEVEL SECURITY;

-- RLS 策略：只允许认证用户读取启用的配置（不暴露 api_key）
CREATE POLICY "Authenticated users can read active configs"
ON ai_provider_configs FOR SELECT
TO authenticated
USING (is_active = true);
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键，自动生成 |
| name | TEXT | 配置名称，用于 App 展示 |
| provider | TEXT | 提供商标识：kie / modelscope / seedream |
| base_url | TEXT | API 基础 URL |
| api_key | TEXT | API 密钥（敏感，仅服务端使用） |
| model_id | TEXT | 模型 ID |
| input_type | TEXT | 输入类型：text-only / image-required / image-optional |
| category | TEXT | 功能分类：general / logo / avatar / background-removal 等 |
| is_active | BOOLEAN | 是否启用 |
| created_at | TIMESTAMPTZ | 创建时间 |
| updated_at | TIMESTAMPTZ | 更新时间 |

### input_type 说明

| input_type | 说明 | 适用板块 |
|------------|------|----------|
| text-only | 只需要文字输入 | 文生图板块 |
| image-required | 必须提供图片 | 图片编辑、背景移除板块 |
| image-optional | 图片可选（两栖模型） | 文生图、图片编辑板块都可出现 |

### category 说明

| category | 说明 | 示例模型 |
|----------|------|----------|
| general | 通用模型 | Seedream 4.5、Nano Banana Pro |
| logo | Logo 生成 | Logo 极简风格、Logo 3D风格 |
| avatar | 头像生成 | AI 头像生成 |
| background-removal | 背景移除 | Recraft 背景移除 |
| poster | 海报生成 | 海报设计模型 |

> 💡 `category` 字段可根据业务需求自由扩展，无需修改表结构。

---

## 迁移现有表（如果已有旧表）

如果你已经有旧版本的表（包含 model_type 字段），执行以下迁移脚本：

```sql
-- 添加新字段
ALTER TABLE ai_provider_configs 
ADD COLUMN IF NOT EXISTS input_type TEXT DEFAULT 'text-only' 
    CHECK (input_type IN ('text-only', 'image-required', 'image-optional'));

ALTER TABLE ai_provider_configs 
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'general';

-- 根据现有 model_type 自动填充 input_type（如果有 model_type 字段）
UPDATE ai_provider_configs SET input_type = 'text-only' WHERE model_type = 'text-to-image';
UPDATE ai_provider_configs SET input_type = 'image-required' WHERE model_type IN ('image-edit', 'remove-background');
UPDATE ai_provider_configs SET input_type = 'image-optional' WHERE model_type = 'image-generation';

-- 根据 model_type 设置 category
UPDATE ai_provider_configs SET category = 'background-removal' WHERE model_type = 'remove-background';

-- 添加注释
COMMENT ON COLUMN ai_provider_configs.input_type IS '输入类型: text-only(仅文字), image-required(必须图片), image-optional(图片可选)';
COMMENT ON COLUMN ai_provider_configs.category IS '功能分类: general(通用), logo(Logo生成), avatar(头像), background-removal(背景移除) 等';

-- 创建新索引
CREATE INDEX IF NOT EXISTS idx_input_type ON ai_provider_configs(input_type);
CREATE INDEX IF NOT EXISTS idx_category ON ai_provider_configs(category);
CREATE INDEX IF NOT EXISTS idx_category_input_type ON ai_provider_configs(category, input_type, is_active);

-- 可选：删除旧的 model_type 字段和索引
-- DROP INDEX IF EXISTS idx_model_type;
-- ALTER TABLE ai_provider_configs DROP COLUMN IF EXISTS model_type;
```

---

## 添加配置

### Kie 提供商配置

Kie 提供商支持多种模型，每种模型有不同的功能：

#### 1. Seedream 4.5 文生图

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES (
    'Kie Seedream 4.5 文生图',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'seedream/4.5-text-to-image',
    'text-only',
    'general'
);
```

#### 2. Seedream 4.5 图片编辑

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES (
    'Kie Seedream 4.5 图片编辑',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'seedream/4.5-edit',
    'image-required',
    'general'
);
```

#### 3. 背景移除

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES (
    'Kie 背景移除',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'recraft/remove-background',
    'image-required',
    'background-removal'
);
```

#### 4. Nano Banana Pro (图片生成/图生图)

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES (
    'Kie Nano Banana Pro',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'nano-banana-pro',
    'image-optional',
    'general'
);
```

### Logo 生成模型（示例：四种风格）

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES 
    ('Logo 极简风格', 'kie', 'https://api.kie.ai', 'your-api-key', 'logo-minimalist', 'text-only', 'logo'),
    ('Logo 3D风格', 'kie', 'https://api.kie.ai', 'your-api-key', 'logo-3d', 'text-only', 'logo'),
    ('Logo 复古风格', 'kie', 'https://api.kie.ai', 'your-api-key', 'logo-vintage', 'text-only', 'logo'),
    ('Logo 卡通风格', 'kie', 'https://api.kie.ai', 'your-api-key', 'logo-cartoon', 'text-only', 'logo');
```

### ModelScope 配置

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES (
    'ModelScope Qwen Image',
    'modelscope',
    'https://api-inference.modelscope.cn',
    'your-modelscope-api-key',
    'Qwen/Qwen-Image-2512',
    'text-only',
    'general'
);
```

### Seedream (火山引擎) 配置

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, input_type, category)
VALUES (
    'Seedream 4.5',
    'seedream',
    'https://ark.cn-beijing.volces.com',
    'your-ark-api-key',
    'doubao-seedream-4-5-251128',
    'text-only',
    'general'
);
```

---

## 删除配置

```sql
-- 按 ID 删除
DELETE FROM ai_provider_configs WHERE id = 'your-config-uuid';

-- 按名称删除
DELETE FROM ai_provider_configs WHERE name = 'Kie Seedream 4.5 文生图';

-- 按提供商删除所有
DELETE FROM ai_provider_configs WHERE provider = 'kie';

-- 按分类删除
DELETE FROM ai_provider_configs WHERE category = 'logo';
```

---

## 更新配置

```sql
-- 更新 API Key
UPDATE ai_provider_configs 
SET api_key = 'new-api-key', updated_at = now()
WHERE name = 'Kie Seedream 4.5 文生图';

-- 禁用配置
UPDATE ai_provider_configs 
SET is_active = false, updated_at = now()
WHERE id = 'your-config-uuid';

-- 更新输入类型
UPDATE ai_provider_configs 
SET input_type = 'image-required', updated_at = now()
WHERE model_id = 'seedream/4.5-edit';

-- 更新分类
UPDATE ai_provider_configs 
SET category = 'avatar', updated_at = now()
WHERE name = 'AI 头像生成';
```

---

## 查询配置

### 基础查询

```sql
-- 查询所有启用的配置
SELECT id, name, provider, base_url, model_id, input_type, category 
FROM ai_provider_configs 
WHERE is_active = true;

-- 按提供商查询
SELECT * FROM ai_provider_configs 
WHERE provider = 'kie' AND is_active = true;
```

### 按功能板块查询（核心用法）

```sql
-- 文生图板块：不需要图片输入 + 通用分类
SELECT * FROM ai_provider_configs 
WHERE input_type IN ('text-only', 'image-optional') 
  AND category = 'general' 
  AND is_active = true;

-- 图片编辑板块：需要或支持图片输入 + 通用分类
SELECT * FROM ai_provider_configs 
WHERE input_type IN ('image-required', 'image-optional') 
  AND category = 'general' 
  AND is_active = true;

-- Logo 生成板块：直接按 category 过滤
SELECT * FROM ai_provider_configs 
WHERE category = 'logo' AND is_active = true;

-- 背景移除板块：按 category 过滤
SELECT * FROM ai_provider_configs 
WHERE category = 'background-removal' AND is_active = true;

-- 头像生成板块
SELECT * FROM ai_provider_configs 
WHERE category = 'avatar' AND is_active = true;
```

### 查询所有分类

```sql
-- 获取所有已使用的分类
SELECT DISTINCT category FROM ai_provider_configs WHERE is_active = true;
```

---

## App 端请求参数说明

以下参数由 App 在调用 API 时传递，不再存储在配置表中：

### 通用请求结构

```json
{
  "config_id": "uuid-of-config",
  "prompt": "用户输入的提示词",
  "image_url": "单个图片URL（用于背景移除）",
  "image_urls": ["图片URL数组（用于图片编辑）"],
  "params": {
    // 各模型特定参数
  }
}
```

### Kie Seedream 4.5 文生图请求

```json
{
  "config_id": "uuid",
  "prompt": "一只可爱的猫咪",
  "params": {
    "aspect_ratio": "1:1",
    "quality": "basic"
  }
}
```

### Kie Seedream 4.5 图片编辑请求

```json
{
  "config_id": "uuid",
  "prompt": "将衣服颜色改为红色",
  "image_urls": ["https://example.com/image.jpg"],
  "params": {
    "aspect_ratio": "1:1",
    "quality": "basic"
  }
}
```

### Kie 背景移除请求

```json
{
  "config_id": "uuid",
  "image_url": "https://example.com/image.jpg"
}
```

### Kie Nano Banana Pro 请求

```json
{
  "config_id": "uuid",
  "prompt": "一只可爱的猫咪",
  "image_urls": [],
  "params": {
    "aspect_ratio": "1:1",
    "resolution": "1K",
    "output_format": "png"
  }
}
```

### ModelScope 请求参数

```json
{
  "config_id": "uuid",
  "prompt": "一只可爱的猫咪",
  "params": {}
}
```

### Seedream (火山引擎) 请求参数

```json
{
  "config_id": "uuid",
  "prompt": "一只可爱的猫咪",
  "params": {
    "size": "2K",
    "watermark": false
  }
}
```

---

## 模型分类速查表

| input_type | category | 说明 | 适用板块 |
|------------|----------|------|----------|
| text-only | general | 通用文生图 | 文生图 |
| text-only | logo | Logo 生成 | Logo 板块 |
| text-only | avatar | 头像生成 | 头像板块 |
| image-required | general | 图片编辑 | 图片编辑 |
| image-required | background-removal | 背景移除 | 背景移除 |
| image-optional | general | 两栖模型 | 文生图、图片编辑 |

---

## App 端 Swift 示例代码

```swift
enum FeatureSection: String {
    case textToImage = "text-to-image"
    case imageEdit = "image-edit"
    case logoGeneration = "logo"
    case backgroundRemoval = "background-removal"
    case avatarGeneration = "avatar"
}

func fetchModels(for section: FeatureSection) async throws -> [AIProviderConfig] {
    let query: PostgrestFilterBuilder
    
    switch section {
    case .textToImage:
        // 文生图板块：不需要图片输入 + 通用分类
        query = supabase.from("ai_provider_configs")
            .select()
            .in("input_type", values: ["text-only", "image-optional"])
            .eq("category", value: "general")
            .eq("is_active", value: true)
        
    case .imageEdit:
        // 图片编辑板块：需要或支持图片输入 + 通用分类
        query = supabase.from("ai_provider_configs")
            .select()
            .in("input_type", values: ["image-required", "image-optional"])
            .eq("category", value: "general")
            .eq("is_active", value: true)
        
    case .logoGeneration, .backgroundRemoval, .avatarGeneration:
        // 专用板块：直接按 category 过滤
        query = supabase.from("ai_provider_configs")
            .select()
            .eq("category", value: section.rawValue)
            .eq("is_active", value: true)
    }
    
    return try await query.execute().value
}
```
