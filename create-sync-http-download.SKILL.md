---
name: create-sync-http-download
summary: '创建一个 CMS 专用的下载任务技能：通过 REST API POST XML 拉取 FileInfoData 列表，构建队列并进行多线程可断点续传下载。'
description: |
  该技能专注于 CMS 场景。
  它描述如何通过 `AppGlobal.cmsUrl + '/api/pm/players/filelist?authentication-token=' + AppGlobal.cmsToken` 发起 HTTP POST 请求，向服务器提交 XML 任务查询，并解析返回的 XML `PublishFileInformation` 列表。

  每个响应元素 `FileItem` 需映射为下载任务：
  - 源文件 URL = `AppGlobal.cmsUrl + m_strShortPath`
  - 目标文件路径 = `Utils.getFilePath(m_strDestFile, m_nContentType)`

  最终生成一个带队列管理的多线程下载实现，支持 HTTP 断点续传、重试、任务持久化和基于 `m_tmFileModify` 的文件更新判断。
arguments:
  - name: cmsApiHost
    description: 'CMS 根地址，如 AppGlobal.cmsUrl。'
    type: string
  - name: cmsToken
    description: 'CMS 身份验证令牌，拼接到 API URL 中。'
    type: string
  - name: xmlRequestBody
    description: '用于查询文件列表的 XML POST 负载。'
    type: string
  - name: concurrency
    description: '下载并发 worker 数量。'
    type: integer
  - name: queueMode
    description: '队列调度模式，例如 FIFO、LIFO、按优先级调度。'
    type: string
  - name: retryPolicy
    description: '失败重试策略，包含重试次数与退避策略。'
    type: object
  - name: timeout
    description: 'HTTP 请求超时时间（秒）。'
    type: integer
  - name: persistence
    description: '队列与任务状态持久化方式，例如 JSON 文件、SQLite。'
    type: string
---

## 使用说明

1. 确定 REST API 终结点：`AppGlobal.cmsUrl + '/api/pm/players/filelist?authentication-token=' + AppGlobal.cmsToken`。
2. 构造 XML POST 请求体，示例：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ContentList ContentType="108" StartFtpTime="25/03/2026 13:31:29" FtpPeriod="7" FtpContent="128" strUniqueName="E823_8FA6_BF53_0001_001B_448B_4C2B_CC05." strPlayer="test827" organization="SP" strTask="20260325213129">
  <Content Name="20251120123253" />
</ContentList>
```

3. 发起 POST 请求并解析响应 XML。解析节点为 `<PublishFileInformation><FileItem .../></PublishFileInformation>`。
4. 将每个 `FileItem` 转换为下载任务：
   - `url = cmsUrl + m_strShortPath`
   - `targetPath = Utils.getFilePath(m_strDestFile, m_nContentType)`
   - `lastModified = m_tmFileModify`
   - `size = m_dwFileSize`（如果可用）
   - `status, contentType, uuid, id` 等可用于任务过滤或版本比较。
5. 任务入队并持久化，以支持程序重启后的恢复和继续下载。
6. 启动 `concurrency` 个 worker 并发下载：
   - 检查目标文件是否已存在且 `m_tmFileModify` 已更新；如果仅部分下载，则使用 HTTP `Range` 续传。
   - 使用临时文件（例如 `*.part`）写入下载数据，并在完成后重命名为最终目标文件。
   - 如果服务器不支持 `Range`，则退回到单连接完整下载。
   - 当某个任务下载失败时，不中断整体调度流程；将该任务重新加入队列尾部，`retryCount + 1`，并继续处理下一个任务。
   - 每个任务最多重试 `AppGlobal.fileTransferRetries` 次；若重试次数超过该上限，则从队列中移除，并记录为最终失败。
   - 直到所有任务都被处理完成或全部失败退出，调度流程结束。
7. 任务完成后记录状态，包括 `success`、`failed`、`retryCount`、`downloadedBytes`、`totalBytes`。

## DCM 特定流程

- POST URL: `AppGlobal.cmsUrl + '/api/pm/players/filelist?authentication-token=' + AppGlobal.cmsToken`
- 请求头应包含 `Content-Type: application/xml; charset=UTF-8`。
- 返回 XML 格式类似：

```xml
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<PublishFileInformation Signature="DCM FTP Manager Version 1.00 - Publish File Information List">
  <FileItem m_Status="0" m_dtEffDateFr="29/05/2026 17:32:41" m_dtEffDateTo="29/05/2036 17:32:41" m_dwFileSize="-1" m_nContentType="108" m_nTransferType="1" m_strDestFile="20251120123253.xml" m_strFileTitle="20251120123253" m_strMD5="" m_strSHA1="" m_strShortPath="api/msg/ahMessages/xmlcontent/13" m_tmFileCreate="" m_tmFileModify="25/03/2026 17:09:59" m_uiID="13" uuid=""/>
  ...
</PublishFileInformation>
```

- 每个 `FileItem` 的下载源为 `cmsUrl + m_strShortPath`；根据返回的 `m_nContentType` 和 `m_strDestFile`，使用 `Utils.getFilePath(...)` 计算本地保存路径。
- 对于 `m_tmFileModify` 字段，建议使用它与本地文件最后修改时间比对，决定是否需要重新下载或继续下载。

## 任务映射规则

- `url`：`cmsUrl + m_strShortPath`
- `targetPath`：`Utils.getFilePath(m_strDestFile, m_nContentType)`
- `partialPath`：`targetPath + '.part'`
- `currentBytes`：如果 `.part` 文件存在，则记录其大小，用于 `Range` 续传
- `remoteLastModified`：解析 `m_tmFileModify` 为时间对象
- `remoteSize`：`m_dwFileSize`，若为 -1 则表示未知

## 断点续传与更新策略

- 先对源文件发送 `HEAD` 请求，如果返回 `Accept-Ranges: bytes`，则支持断点续传。
- 如果本地 `.part` 文件存在且服务器支持 `Range`，则从 `Range: bytes={currentBytes}-` 继续下载。
- 如果目标文件已存在，且本地文件最后修改时间不一致或 `m_tmFileModify` 更新，则重新下载或使用 `.part` 续传。
- 推荐使用原子重命名操作：完成后将 `download.tmp` 或 `download.part` 重命名为目标路径。

## 队列与并发管理

- 队列类型可选：FIFO、LIFO、优先级队列。
- 每个 worker 从队列中取出任务并开始下载。
- 当任务下载失败时，将其重新加入队列尾部，同时将 `retryCount` 加一，并继续处理下一个任务。
- 每个任务最多重试 `AppGlobal.fileTransferRetries` 次；若已超过该次数，则从队列中移除并标记为最终失败。
- 失败重试可结合 `retryPolicy` 进行指数退避；在所有任务处理完成前，调度器持续轮询队列直到队列为空。
- 可选地实现任务优先级和分批调度。
- 支持“重设队列”操作：停止所有正在执行的任务、清空待处理队列，并将整个下载队列视为结束。
- 支持“获取队列状态”查询：返回当前队列状态、是否所有任务已结束、队列最后一次完成结果是否成功或失败、失败任务数、成功任务数。
- 支持“加入任务”操作：可以单个或批量加入任务到队列（支持去重）；新加入任务默认状态为 `pending`，会在下一轮调度中被 worker 拿取。
- 支持“移除任务”操作：可以按 `id` 单个或批量移除队列中的任务（包括 pending、failed、skipped 状态的任务），并持久化变更。
- 当 `pollingInterval` 或 `buildRequestBody` 为空时，禁用轮询，不再自动发起周期性拉取或任务调度。
- 支持“加入任务并启动处理”操作：可以在加入单个或多个任务后，立即启动任务处理逻辑，让新任务进入 worker 调度。

## 持久化建议

- 小规模实现：使用 JSON 文件保存任务队列与状态。
- 生产环境：建议使用 SQLite 或本地数据库保存任务、进度和历史。
- 状态字段包括：`id`, `url`, `targetPath`, `status`, `downloadedBytes`, `totalBytes`, `retryCount`, `lastModified`, `updatedAt`。

## 示例提示词

- "请生成一个 Dart 实现，它会向 `AppGlobal.cmsUrl + '/api/pm/players/filelist?authentication-token=' + AppGlobal.cmsToken` POST XML，解析 `PublishFileInformation`，并在 `downloads/` 下并发下载所有文件，支持 HTTP Range 断点续传。"
- "给我一个包含 `FileInfoData` 映射、队列持久化、并发 worker 和重试策略的 DCM 下载器设计文档。"
- "把这个技能改成 Kotlin 实现，使用 OkHttp 进行 POST 和 Range 下载。"

## 何时使用

- 需要为 CMS 集成自动下载任务流程时
- 需要从 CMS REST API 获取文件列表并执行可靠的多线程下载时
- 需要支持断点续传和基于 `m_tmFileModify` 的文件更新判断时
