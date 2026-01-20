# 总体实现流程分为三步：
第一步：POST 创建任务 → 得到 task_id
第二步：GET 查询任务状态 → 拿到图片 URL
第三步：curl 下载图片

1. 发起异步生成请求任务

```
curl --request POST \
  --url https://api-inference.modelscope.cn/v1/images/generations \
  --header "Authorization: Bearer <MODELSCOPE_api_key>" \
  --header "Content-Type: application/json" \
  --header "X-ModelScope-Async-Mode: true" \
  --data '{
    "model": "Qwen/Qwen-Image-2512",
    "prompt": "A golden cat"
  }'
```

运行成功会得到以下类似代码：

```
{
  "task_id": "your-task-id"
}
```

2. 轮询任务状态

```
curl --request GET \
  --url https://api-inference.modelscope.cn/v1/tasks/<task_id> \
  --header "Authorization: Bearer ms-2b6f1cf2-7676-4c2b-841c-a8c3cd767067" \
  --header "Content-Type: application/json" \
  --header "X-ModelScope-Task-Type: image_generation"
```

本处的 `task_id` 就是上轮异步生成请求返回的 `task_id`，替换即可。最终返回的结果字段中的 `task_status` 如果是 `SUCCEEDED`，则表示任务完成，可以获取结果了；如果是 `FAILED`，就代表任务失败。否则继续轮询即可、直到任务完成（SUCCEEDED 或者 FAILED）。

假如是 SUCCEEDED 的话，返回结果类似如下：

```
{"input":{"guidanceScale":7.5,"height":1280,"negativePrompt":"","numInferenceSteps":30,"outputs":{},"prompt":"A golden cat","sampler":"Euler a","seed":999541655,"timeTaken":41152.74262428284,"weight":0},"output_images":["https://muse-ai.oss-cn-hangzhou.aliyuncs.com/img/3134f467f50a49b9b8196088bf8c983f.png"],"request_id":"6cea75d7-c494-4072-ae85-e02a2dd19d35","task_id":"","task_status":"SUCCEED","time_taken":41152.74262428284}
```

3. 下载图片

需要把上一步返回结果中的 `output_images` 字段中的 URL 拿出来，使用 curl 命令下载即可。
