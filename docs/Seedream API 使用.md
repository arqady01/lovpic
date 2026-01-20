# 请求参数

输入代码示例

```
curl -X POST https://ark.cn-beijing.volces.com/api/v3/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ARK_API_KEY>" \
  -d '{
    "model": "doubao-seedream-4-5-251128",
    "prompt": "生成狗狗趴在草地上的近景画面",
    "image": "https://ark-project.tos-cn-beijing.volces.com/doc_image/seedream4_imageToimage.png",
    "sequential_image_generation": "disabled",
    "response_format": "url",
    "size": "2K",
    "stream": false,
    "watermark": true
}'
```

1. **ARK_API_KEY** 数据类型：`string`
     传入的 api_key
1. **model** 数据类型：`string`
     请求使用模型的 model id，比如示例代码中的 `doubao-seedream-4-5-251128` 就是 seedream4.5 模型的 model id
2. **prompt** 数据类型：`string` 
     用于生成图像的提示词，支持中英文。建议不超过300个汉字或600个英文单词。字数过多信息容易分散，模型可能因此忽略细节，只关注重点，造成图片缺失部分元素。
3. **image** 数据类型：`string/array`
     输入的图片信息，支持 URL 或 Base64 编码。注意图片格式仅支持jpeg、png
     - 图片URL：请确保图片URL可被访问。
     - Base64编码：请遵循此格式 `data:image/<图片格式>;base64,<Base64编码>`。注意 `<图片格式>` 需小写，如 `data:image/png;base64,<base64_image>`。
4. **size** 数据类型：`string`
     指定生成图像的尺寸信息，支持以下两种方式，不可混用。
     - 方式 1：指定生成图像的分辨率，并在prompt中用自然语言描述图片宽高比、图片形状或图片用途，最终由模型判断生成图片的大小。
          - 可选值：2K、4K
     - 方式 2：指定生成图像的宽高像素值：
          - 默认值：2048x2048
          - 总像素取值范围：[2560x1440=3686400, 4096x4096=16777216] 
          - 宽高比取值范围：[1/16, 16]
          采用方式 2 时，需同时满足总像素取值范围和宽高比取值范围。其中，总像素是对单张图宽度和高度的像素乘积限制，而不是对宽度或高度的单独值进行限制。
          - **有效示例**：3750x1250
          总像素值 3750x1250=4687500，符合 [3686400, 16777216] 的区间要求；宽高比 3750/1250=3，符合 [1/16, 16] 的区间要求，故该示例值有效。
          - **无效示例**：1500x1500
          总像素值 1500x1500=2250000，未达到 3686400 的最低要求；宽高 1500/1500=1，虽符合 [1/16, 16] 的区间要求，但因其未同时满足两项限制，故该示例值无效。
5. **sequential_image_generation** 数据类型：`string`，默认值为 `disabled`
     请保持为默认值 `disabled`，也就是关闭组图功能，只生成一张图。
6. **stream** 数据类型：`Boolean`，默认值为 `false`
     控制是否开启流式输出模式。
     - false：非流式输出模式，等待图片全部生成结束后再一次性返回所有信息。
     - true：流式输出模式，即时返回每张图片输出的结果。
7. **response_format** 数据类型：`string`，默认值为 `url`
     用于指定生成图像的返回格式。生成的图片为 jpeg 格式，支持以下两种返回方式：
     - url：返回图片下载链接；**链接在图片生成后24小时内有效，请及时下载图片。**
     - b64_json：以 Base64 编码字符串的 JSON 格式返回图像数据。
8. **watermark**  数据类型：`Boolean`，默认值为 `true`
     是否在生成的图片中添加水印。
     - false：不添加水印。
     - true：在图片右下角添加“AI生成”字样的水印标识。

# 非流式响应参数

输出示例代码

```
{
    "model": "doubao-seedream-4-5-251128",
    "created": 1757323224,
    "data": [
        {
            "url": "https://...",
            "size": "1760x2368"
        }
    ],
    "usage": {
        "generated_images": 1,
        "output_tokens": 16280,
        "total_tokens": 16280
    }
}
```

1. model 数据类型：`string`
     本次请求使用的模型 ID （模型名称-版本）。
2. created 数据类型：`integer`
     本次请求创建时间的 Unix 时间戳（秒）。
3. data 数据类型：`array`
     输出图像的信息。
     属性值有两种可能，成功或者失败
     生成成功的图片信息：
          - `data.url` 数据类型：`string`
               图片的 url 信息，当 response_format 指定为 url 时返回。该链接将在生成后 24 小时内失效，请务必及时保存图像。
          - `data.b64_json` 数据类型：`string`
               图片的 base64 信息，当 response_format 指定为 b64_json 时返回。
          - `data.size` 数据类型：`string`
               图像的宽高像素值，格式 <宽像素>x<高像素>，如2048×2048。
     图片生成失败的错误信息：
          - `data.error.code`
               某张图片生成错误的错误码，请参见错误码。
          - `data.error.message`
               某张图片生成错误的提示信息。
4. usage object
     本次请求的用量信息。
     - `usage.generated_images` 数据类型：`integer`
          模型成功生成的图片张数，不包含生成失败的图片。
     - `usage.output_tokens` 数据类型：`integer`
          模型生成的图片花费的 token 数量。计算逻辑为：计算 sum(图片长*图片宽)/256 ，然后取整。
     - `usage.total_tokens` 数据类型：`integer`
          本次请求消耗的总 token 数量。当前不计算输入 token，故与 output_tokens 值一致。