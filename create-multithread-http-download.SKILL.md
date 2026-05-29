---
name: create-multithread-http-download
summary: '创建一个多线程可断点续传的 HTTP 下载器技能（通过 REST API 获取任务列表，支持队列和并发）。'
description: |
  该技能针对场景：先通过 REST API 拉取下载任务列表（每个元素包含源文件 URL 与目标保存路径），然后将这些任务放入队列，由多个并发 worker 执行下载。

  特性要求：
  - 从指定 REST API 获取任务列表（JSON 数组，每项含 `url`、`targetPath`、可选 `priority`、`id`）
  - 支持并发下载（可配置并发数）
  - 支持断点续传（基于 HTTP Range，写入文件的指定偏移）
  - 支持队列策略：FIFO / 优先级 / LIFO
  - 支持失败重试与退避（可配置重试次数与策略）
  - 进度与状态回调（每个任务的下载进度、速率、剩余时间估计）
  - 持久化队列和任务状态以实现程序重启后继续

  输出目标：
  - 清晰的实现方案与流程
  - REST API 请求/响应示例与 JSON schema
  - 语言示例实现（首选：Dart）含可运行示例代码片段
  - 可选扩展建议（认证、速率限制、带宽控制）
arguments:
  - name: taskList
    description: '下载任务列表，支持 URL、目标文件名、优先级等字段。'
    type: object
  - name: concurrency
    description: '并发下载线程/工作器数量。'
    type: integer
  - name: queueMode
    description: '队列调度模式，例如 FIFO、LIFO 或按优先级调度。'
    type: string
  - name: retryPolicy
    description: '下载失败重试策略，包括次数和退避方式。'
    type: object
  - name: savePath
    description: '下载文件的本地保存目录或路径模板。'
    type: string
  - name: timeout
    description: '单个下载请求超时时间（秒）。'
    type: integer
  - name: restApiEndpoint
    description: '用于拉取任务列表的 REST API 地址（返回 JSON 数组）。'
    type: string
---

## 使用说明

1. 询问用户所需下载的 URL 列表和并发控制参数。
2. 设计一个任务队列管理器，支持多线程 worker 消费下载任务。
3. 生成示例实现代码，包含：
   - 下载任务实体
   - 并发队列调度
   - HTTP 请求处理、写文件和状态回调
   - 错误重试、超时和取消支持
4. 提供测试场景示例和常见改进方向。

## 目标输出

- 可直接使用的下载器设计方案
- 适配多种语言/平台的实现建议
- 代码示例（例如 Dart、Python、Java 或 Node.js）
- 任务队列状态和进度反馈格式

## 何时使用

- 需要在 Claude 中生成或设计一个带队列的并行 HTTP 下载解决方案时
- 需要快速定义下载任务、并发参数、错误处理和队列策略时
- 需要将下载功能集成到客户端应用或后台服务时

## 详细流程（针对 REST API -> 队列 -> 多线程下载）

1. 拉取任务列表：调用 `restApiEndpoint`，预期返回 JSON 数组，示例格式见下。
2. 验证并规范化每个任务（必须包含 `url` 与 `targetPath`；如果没有 `id`，生成唯一 id）。
3. 将任务放入持久化队列（本地 DB / 文件，例如 SQLite、LevelDB 或 JSON 文件），以便程序崩溃/重启后能恢复进度。
4. 启动 N 个并发 worker（`concurrency`），每个 worker 从队列领取任务并执行下载。
5. 下载实现：
   - 先请求 `HEAD` 或 `GET` 带 `Range` 的请求以确认是否支持断点续传以及文件大小。
   - 如果支持 `Accept-Ranges: bytes`，按区间并发或按单任务内分段写入；否则使用单连接顺序下载。
   - 使用原子写入与临时文件命名（例如 `file.part`），并在完成后重命名为目标文件。
   - 在下载过程中定期将已完成字节数写回任务状态（用于恢复）。
6. 错误处理：当单次连接失败时按 `retryPolicy` 重试，采用指数退避（exponential backoff），超出次数则标记为失败并记录原因。
7. 进度上报：支持订阅或轮询队列状态，返回单个任务的 `downloadedBytes`、`totalBytes`、`status`、`speedBps`、`eta`。
8. 优先级与调度：实现简单优先队列或分级队列，优先级高的任务先被 worker 拿走。

## REST API JSON schema（示例）

```json
[
  {
    "id": "task-1",
    "url": "https://example.com/file1.zip",
    "targetPath": "downloads/file1.zip",
    "priority": 10
  }
]
```

必需字段：`url`, `targetPath`。可选字段：`id`, `priority`, `headers`（用于自定义请求头），`checksum`。

## 决策点与实现建议

- 持久化方式：轻量建议 JSON 文件或 SQLite。对于大量任务选择 DB。
- 并发模型：Dart 中可用 `Isolate` 或纯异步 `Future` + `HttpClient` 并发。Isolate 更适合CPU密集操作或大量并行 I/O 写入场景。
- 断点续传：需要服务器支持 `Range`，否则只能从头开始或实现 chunked resume（更复杂）。

## Dart 简洁示例（核心片段）

```dart
// 高层次伪代码片段，演示要点
class DownloadTask { String id, url, targetPath; int downloaded = 0; int? total; }

Future<void> workerLoop(Queue<DownloadTask> q, HttpClient client) async {
  while (true) {
    final task = q.removeFirst();
    final file = File('${task.targetPath}.part');
    final raf = await file.open(mode: FileMode.append);
    try {
      final request = await client.getUrl(Uri.parse(task.url));
      if (task.downloaded > 0) {
        request.headers.set('Range', 'bytes=${task.downloaded}-');
      }
      final response = await request.close();
      if (response.statusCode == 206 || response.statusCode == 200) {
        await for (final chunk in response) {
          await raf.writeFrom(chunk);
          task.downloaded += chunk.length;
          // persist progress periodically
        }
        await raf.close();
        await File(task.targetPath).rename(file.path);
      } else {
        throw Exception('Unexpected status ${response.statusCode}');
      }
    } finally {
      await raf.close();
    }
  }
}
```

该示例强调：使用 `Range` 头、以追加方式打开临时文件、在完成后原子重命名。实际实现需要加入重试、并发安全的队列和持久化。

## 示例提示词（给 Claude）

- "生成一个 Dart 实现，功能：从 `https://api.example/tasks` 拉取任务，concurrency=4，支持 Range resume，持久化队列到 `downloads/queue.json`。"
- "把上面的实现改为 Node.js 版本，使用 `axios` 与 `fs.createWriteStream`。"

## 后续改进建议

- 添加身份验证（API token、签名URL）。
- 支持速率限制与带宽分配。
- 在 UI 层展示实时进度与错误详情。

