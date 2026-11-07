---
name: message-sync-service
description: "用于在 DCM Flutter 项目中实现或维护 MessageSyncService、AHMessage 消息内容同步和下载。收到 CMS WebSocket 的 CMD_AH_MESSAGE、MessageInfo.fromBuffer、按 messageName 请求文件清单、解析 PublishFileInformation XML、处理断点续传或要求串行排队时使用本 Skill。"
---

# Message Sync Service

## 目标与范围

在 DCM Flutter 客户端实现 `MessageSyncService`，接收 `MessageInfo` 并按入队顺序逐条同步 AHMessage 内容。每个消息的文件清单和全部文件下载必须完成后，才能开始下一个消息；队列为空时服务保持等待状态，后续消息到达后继续工作。

开始编码前检查本 Skill 提到的类和 API 是否仍与当前分支一致。优先复用仓库里的 WebSocket、HTTP、XML、路径和断点续传实现；不要复制第二套通用下载器。

## 项目锚点

- WebSocket 分发：`lib/backend/net/cms_websocket_service.dart`
- 消息协议：`lib/proto/websocket_def.pb.dart` 中的 `MessageInfo` 与 `CommandType.CMD_AH_MESSAGE`
- 请求 XML：`PlayerTaskFile.genHTTPRequest()`，位于 `lib/backend/net/player_task_file.dart`
- 请求常量：`cDCMAHMESSAGETYPE`、`cSyncAHMESSAGE`、`cmsGETFILELISTURL`，位于 `lib/backend/constants.dart` 和 `player_task_file.dart`
- CMS HTTP POST：`PlayerLogFile.httpPostAction()`，位于 `lib/backend/net/player_log_file.dart`
- 文件清单解析：`XmlFilePro`、`XmlItem`，位于 `lib/backend/xmlfile/`
- 清单签名常量：`cFLSignature`，位于 `lib/backend/net/player_path_service.dart`
- 文件元数据：`FileInfoData.getFromXML(XmlItem)`，位于 `lib/backend/models/file_info_data.dart`。它是实例方法，不是静态工厂。
- 可续传下载：`ContentDownloadTask`、`ContentDownloadQueue`、`ContentDownloader`，位于 `lib/backend/services/content_downloader.dart`
- 源 URL / 目标路径：`ContentDownloadTask.fromFileInfoData()` 会根据 `strShortPath`、CMS URL、`strDestFile`、`nContentType` 和 `tmFileModify` 构造下载任务。

## 实现流程

1. 在 `lib/backend/net/message_sync_service.dart` 实现 `MessageSyncService`，让它成为 AHMessage 同步的唯一队列所有者。由现有 CMS WebSocket 服务持有或注入它，并在 WebSocket 服务销毁时释放；不要在每个消息回调中临时创建服务。
2. 在 `CommandType.CMD_AH_MESSAGE` 分支用 `MessageInfo.fromBuffer(message.payload)` 解析二进制 Protobuf payload，然后将结果交给 `MessageSyncService.enqueue()`。不要把 payload 当 JSON 或字符串解析。
3. WebSocket 分发回调不能等待网络下载。将 enqueue/drain 以非阻塞方式启动，同时保留单条队目的完成 Future 或可等待的 `idle` 信号，供测试和生命周期协调使用。
4. 用 FIFO 队列保存待处理消息，并用单一 drain loop 或等价的串行锁保证任意时刻最多只有一个 `MessageInfo` 正在处理。不要为每个 enqueue 启动互不相关的 async worker。处理期间到达的消息追加到队尾，不丢弃、不并发执行。
5. 生成清单请求 XML：

   ```dart
   final request = PlayerTaskFile.genHTTPRequest(
     [messageInfo.messageName],
     cDCMAHMESSAGETYPE,
     PlayerTaskFile.nSyncPeriod,
     cSyncAHMESSAGE,
     DateFormat('yyyyMMddHHmmss').format(DateTime.now()),
   );
   ```

   `messageName` 为空时按协议拒绝该消息并记录日志，不要发出空内容请求。
6. 组装清单 endpoint，遵循现有 CMS URL 约定：先从 `AppGlobal.cmsUrl` 开始，经 `fADDSLASH()` 规范化后追加 `cmsGETFILELISTURL`，再调用 `Utils.addCMSParam()`。使用 `PlayerLogFile.httpPostAction(endpoint, request, 'application/xml; charset=utf-8')` POST 请求。
7. 检查 HTTP 结果状态和响应体。用 `XmlFilePro('PublishFileInformation').loadXml(response)` 解析 XML；核对 `PublishFileInformation` 根节点，并用 `getSignature() == cFLSignature` 验证签名。基础 `XmlFile` 没有 `getSignature()`，不要在它上面调用该方法。解析失败、服务端返回错误或签名不匹配时，将当前消息标记失败并记录可诊断日志，随后继续队列中的下一条消息。
8. 遍历每一个 `FileItem`：创建 `FileInfoData()`，调用 `getFromXML(fileItem)`，保留服务端的 `strShortPath`、`strDestFile`、`nContentType`、`dwFileSize`、`tmFileModify`、校验和及状态。XML 中的 `&amp;` 等转义必须由 XML parser 解码，禁止手动拆 XML 字符串。
9. 将每个有效 `FileInfoData` 转成 `ContentDownloadTask.fromFileInfoData(fileInfo, AppGlobal.cmsUrl)`。该工厂负责构造 `cmsUrl + strShortPath` 源 URL 和 `Utils.getFilePath(strDestFile, nContentType)` 目标路径；不要自己用字符串拼 URL 或把附件都写入同一个 content type 目录。尊重文件状态和有效期，不能把 skip/remove 项当成普通新文件下载。
10. 为当前 `MessageInfo` 建立可独立等待完成的下载批次。优先复用 `ContentDownloader` 的 Range、重试和 `tmFileModify` 检查，但不要把“文件任务已加入共享 `ContentSyncService().workQueue`”当成“这条消息的下载已经结束”：共享队列可能同时处理其他业务任务，且已在运行时再次 enqueue 可能提前返回。采用专属批次队列/下载器，或实现能按本批任务 ID 精确等待终态的协调器；批次 Future 只有在本批所有文件成功、跳过或达到最终失败状态后才完成。
11. 下载器应保留 `.part` 断点文件。远端 `tmFileModify` 新于本地目标或 partial 文件时按 downloader 规则重启文件；已有文件未更新时跳过；服务重启后仍能根据目标/partial 文件状态恢复。不要在普通失败路径删除可续传的 partial 文件。
12. 当前消息的批次结束后（包括错误处理完成后）才从 FIFO 取下一条。单个文件或消息失败必须被捕获并报告，不能让 drain loop 永久停止。没有 FileItem 时作为空批次正常结束。
13. 队列排空后让 drain loop 退出并清除 processing 标记，但保留服务实例和可复用的队列，使未来的 enqueue 能重新启动 drain。提供幂等的 `dispose()`，阻止销毁后的新入队并按所有权取消未启动工作；不要在普通队列排空时销毁服务。

## 队列与错误语义

- 每次 enqueue 都按 FIFO 顺序处理一次；除非服务端协议或现有业务明确要求去重，否则不要仅凭 `messageName` 去重不同的 `MessageInfo`。
- 为每个排队项保存自己的完成结果/Future，保证调用方能区分成功、失败和被取消；不要让某条失败消息的异常变成未处理异步异常。
- `_isProcessing` / drain Future 的更新必须无竞态：若新消息恰好在 drain 检查到空队列与清理状态之间入队，必须有新的 drain 被调度，不能遗留永远不处理的任务。
- 日志记录 messageName、文件数和结果即可；避免输出完整响应 XML、认证 query、或敏感消息内容。
- 记录下载总数、成功、跳过、最终失败计数；无效清单响应和单文件失败应能从日志区分。
- 如果 `PlayerLogFile.httpPostAction()` 只返回 `(status, result)`，在消息服务内明确验证 `result` 不为空；不要把请求失败误解释为空清单成功。

## 推荐结构

```dart
class MessageSyncService {
  MessageSyncService({
    required MessageManifestClient manifestClient,
    required MessageBatchDownloader batchDownloader,
  });

  Future<void> enqueue(MessageInfo message);
  Future<void> waitUntilIdle();
  Future<void> dispose();
}
```

以上依赖拆分是测试边界建议，不要求引入多余抽象。如果现有项目风格更适合工厂回调或接口，保持同样的可替换能力：测试应能 fake 清单 POST、文件批次下载和时钟，而不连接真实 CMS。

## 测试要求

新增或复用 `test/` 下的 `package:flutter_test` / `package:test` 测试，至少覆盖：

1. `CMD_AH_MESSAGE` payload 被解析为 `MessageInfo` 并入队；分发不会等待网络请求完成。
2. 连续 enqueue 多条消息时严格 FIFO，同一时刻最多处理一条；人为阻塞第一条下载时，第二条不能开始。
3. 清单 POST 使用正确 URL、CMS query 参数、Content-Type 和请求体字段：`messageName`、`cDCMAHMESSAGETYPE`、`PlayerTaskFile.nSyncPeriod`、`cSyncAHMESSAGE` 及 `yyyyMMddHHmmss` 时间戳。
4. 有多个 `FileItem` 的 XML 能逐项解析并映射正确 source URL、目标路径、content type、`tmFileModify`；XML entities 正确解码。
5. 单条消息的所有文件达到终态后，才开始下一条消息；空列表也能完成当前消息。
6. 最新本地文件跳过，远端更新的文件执行下载，下载中断后可从 Range partial 继续；不要在测试中依赖真实 CMS。
7. HTTP 错误、无效 XML、无效签名和单文件最终失败不会卡住后续队列；队列耗尽后新消息仍能启动处理。
8. `dispose()` 幂等，销毁后拒绝/忽略新消息且不留下后台 Future、Timer 或下载回调。

## 使用此 Skill 时的验收输出

- `MessageSyncService` 的代码路径及 CMS WebSocket 分发接线。
- 清单和下载批次错误如何隔离、队列为何不会并行或卡死。
- 针对性测试结果，以及任何因真实 CMS/平台条件无法验证的项目。

## 何时使用

- 实现 CMS `CMD_AH_MESSAGE`、`MessageInfo.fromBuffer()` 或 AHMessage 内容下载。
- 为 DCM Flutter 增加串行消息同步队列、XML 文件清单解析、断点续传或下载完成屏障。
- 排查 WebSocket 到达多个 AHMessage 后重复下载、并发下载、队列阻塞或后续消息不执行的问题。