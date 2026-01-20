# AI Provider Config SQL 示例

## 设计理念

配置表只存储**服务端必需的配置信息**（API 凭证、端点等），而**用户可控参数**（prompt、图片比例、质量等）由 App 在请求时动态传递。

### 服务端配置 vs 客户端参数

| 类型 | 存储位置 | 示例 |
|------|----------|------|
| 服务端配置 | `ai_provider_configs` 表 | API Key、Base URL、Model ID、Model Type |
| 客户端参数 | App 请求体 | prompt、aspect_ratio、quality、size、image_url |

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
    model_type TEXT,  -- 模型类型: text-to-image, image-edit, remove-background, image-generation
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 添加注释
COMMENT ON TABLE ai_provider_configs IS 'AI 图像生成模型提供商配置表';
COMMENT ON COLUMN ai_provider_configs.provider IS '提供商: kie, modelscope, seedream';
COMMENT ON COLUMN ai_provider_configs.model_type IS '模型类型: text-to-image, image-edit, remove-background, image-generation';

-- 创建索引加速查询
CREATE INDEX idx_provider_active ON ai_provider_configs(provider, is_active);
CREATE INDEX idx_model_type ON ai_provider_configs(model_type);

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
| model_type | TEXT | 模型类型：text-to-image / image-edit / remove-background / image-generation |
| is_active | BOOLEAN | 是否启用 |
| created_at | TIMESTAMPTZ | 创建时间 |
| updated_at | TIMESTAMPTZ | 更新时间 |

---

## 添加配置

### Kie 提供商配置

Kie 提供商支持多种模型，每种模型有不同的功能：

#### 1. Seedream 4.5 文生图

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, model_type)
VALUES (
    'Kie Seedream 4.5 文生图',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'seedream/4.5-text-to-image',
    'text-to-image'
);
```

#### 2. Seedream 4.5 图片编辑

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, model_type)
VALUES (
    'Kie Seedream 4.5 图片编辑',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'seedream/4.5-edit',
    'image-edit'
);
```

#### 3. 背景移除

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, model_type)
VALUES (
    'Kie 背景移除',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'recraft/remove-background',
    'remove-background'
);
```

#### 4. Nano Banana Pro (图片生成/图生图)

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, model_type)
VALUES (
    'Kie Nano Banana Pro',
    'kie',
    'https://api.kie.ai',
    'your-kie-api-key',
    'nano-banana-pro',
    'image-generation'
);
```

### ModelScope 配置

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, model_type)
VALUES (
    'ModelScope Qwen Image',
    'modelscope',
    'https://api-inference.modelscope.cn',
    'your-modelscope-api-key',
    'Qwen/Qwen-Image-2512',
    'text-to-image'
);
```

### Seedream (火山引擎) 配置

```sql
INSERT INTO ai_provider_configs (name, provider, base_url, api_key, model_id, model_type)
VALUES (
    'Seedream 4.5',
    'seedream',
    'https://ark.cn-beijing.volces.com',
    'your-ark-api-key',
    'doubao-seedream-4-5-251128',
    'text-to-image'
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

-- 按模型类型删除
DELETE FROM ai_provider_configs WHERE model_type = 'remove-background';
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

-- 更新模型类型
UPDATE ai_provider_configs 
SET model_type = 'image-edit', updated_at = now()
WHERE model_id = 'seedream/4.5-edit';
```

---

## 查询配置

```sql
-- 查询所有启用的配置
SELECT id, name, provider, base_url, model_id, model_type 
FROM ai_provider_configs 
WHERE is_active = true;

-- 按提供商查询
SELECT * FROM ai_provider_configs 
WHERE provider = 'kie' AND is_active = true;

-- 按模型类型查询
SELECT * FROM ai_provider_configs 
WHERE model_type = 'text-to-image' AND is_active = true;

-- 查询所有背景移除模型
SELECT * FROM ai_provider_configs 
WHERE model_type = 'remove-background' AND is_active = true;
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
    "aspect_ratio": "1:1",    // 可选: 1:1, 4:3, 3:4, 16:9, 9:16, 2:3, 3:2, 21:9
    "quality": "basic"        // 可选: basic (2K), high (4K)
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
  "image_urls": [],           // 可选: 参考图片（最多8张）
  "params": {
    "aspect_ratio": "1:1",    // 可选: 1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9, auto
    "resolution": "1K",       // 可选: 1K, 2K, 4K
    "output_format": "png"    // 可选: png, jpg
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
    "size": "2K",             // 可选: 2K, 4K, 或具体像素如 "2048x2048"
    "watermark": false        // 是否添加水印
  }
}
```

---

## 模型类型说明

| model_type | 说明 | 需要 prompt | 需要图片 |
|------------|------|-------------|----------|
| text-to-image | 文生图 | ✅ | ❌ |
| image-edit | 图片编辑 | ✅ | ✅ (image_urls) |
| remove-background | 背景移除 | ❌ | ✅ (image_url) |
| image-generation | 图片生成（支持图生图） | ✅ | ⚪ 可选 (image_urls) |
