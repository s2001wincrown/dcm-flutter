---
name: cms-websocket-channel
summary: '使用 web_socket_channel 和 Protobuf 为 DCM Flutter 客户端实现 CMS WebSocket 长连接、命令分发、心跳保活、指数退避重连和生命周期管理。'
description: |
  用于当前 DCM Flutter 项目接入 CMS WebSocket 长连接。
  连接地址来自 AppGlobal.cmsUrl + '/ws'，鉴权令牌来自 AppGlobal.cmsToken，优先通过 URL query 参数传递。
  必须使用 lib/proto/websocket_def.pb.dart 定义的 MessageWrapper、CommandType 和业务消息，发送二进制 Protobuf 帧。
  必须实现 30 秒 CMD_HEARTBEAT、90 秒服务端心跳响应超时检测、指数退避重连、CommandType 分发，以及 Flutter Widget/App 生命周期绑定。
  使用 web_socket_channel，不依赖第三方 WebSocket 传输包。
arguments:
  - name: serviceName
    description: 'WebSocket 服务类名，例如 CmsWebSocketService。'
    type: string
  - name: heartbeatIntervalSeconds
    description: '客户端发送 CMD_HEARTBEAT 的间隔，默认 30 秒。'
    type: integer
  - name: heartbeatResponseTimeoutSeconds
    description: '超过多久未收到服务端 CMD_HEARTBEAT 响应判定连接失效，默认 90 秒。'
    type: integer
  - name: reconnectPolicy
    description: '指数退避参数，包括初始延迟、最大延迟、最大尝试次数和抖动。'
    type: object
  - name: lifecycleOwner
    description: '负责关闭和恢复连接的 Widget、State 或应用生命周期管理器。'
    type: string
---

## 使用说明

1. 先确认 `web_socket_channel`、`protobuf` 和 `fixnum` 已在 `pubspec.yaml` 中声明为直接依赖；不要只依赖 lockfile 中的间接依赖。
2. 导入生成协议：
    ```dart
    import 'dart:typed_data';
    import 'package:fixnum/fixnum.dart';
    import 'package:web_socket_channel/web_socket_channel.dart';
    import 'package:your_app/proto/websocket_def.pb.dart';
    ```
    `websocket_def.pb.dart`、`websocket_def.pbenum.dart` 等生成文件由 `websocket_def.protobuf` 生成，不要手工修改生成文件。
3. 从 `AppGlobal.cmsUrl` 构造 WebSocket URI：
   - `http://` 替换为 `ws://`。
   - `https://` 替换为 `wss://`。
   - 规范化末尾 `/`，再追加 `/ws`，避免得到 `//ws`。
   - 将 `AppGlobal.cmsToken` 放入 query 参数 `token`。使用 `Uri` 的 `replace` / `queryParameters`，不要手工拼接未编码的 token。
4. 如果 CMS 服务端约定的鉴权参数名不是 `token`，将参数名集中在 URI 构造方法中配置；不要把 token 硬编码在业务调用处。
5. 长连接服务应由一个可管理的服务对象持有单一 `WebSocketChannel`，避免每次发送消息都创建新连接。
6. 对外提供高层 API，例如：
   - `connect()` / `disconnect()`
    - `sendHeartbeat(String playerId, String status)`
    - `sendCommand(CommandType command, GeneratedMessage payload)`
    - `messages` 流或按 `CommandType` 分流的事件
   - `connectionState` 流或只读状态
  7. `dispose()` 必须取消 Timer、订阅和所有待处理请求，并关闭 channel；关闭后不能继续重连。

## Protobuf 二进制消息格式

所有 WebSocket 帧都必须是 `MessageWrapper.writeToBuffer()` 产生的二进制 Protobuf 数据。不要发送 JSON、文本化 Protobuf 或自定义长度前缀；WebSocket 帧本身已经提供边界。

```dart
final heartbeat = Heartbeat()
  ..playerId = playerId
  ..status = status;
final wrapper = MessageWrapper(
  command: CommandType.CMD_HEARTBEAT,
  protocolId: ProtocolId.PROTOCOL_QC,
  payload: heartbeat.writeToBuffer(),
  timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
);
channel.sink.add(Uint8List.fromList(wrapper.writeToBuffer()));
```

接收时只接受二进制数据，并对单帧解析失败、空帧和未知命令记录日志后忽略，不能终止整个连接监听：

```dart
void onFrame(Object? frame) {
  if (frame is! List<int>) {
    logW('Ignore non-binary CMS WebSocket frame', syncTag);
    return;
  }
  final wrapper = MessageWrapper.fromBuffer(frame);
  dispatch(wrapper);
}
```

## CommandType 分发

`MessageWrapper.command` 必须使用生成的 `CommandType`，禁止使用裸整数或字符串比较。为每个命令建立明确的 `switch` 分支：

- `CMD_HEARTBEAT`：使用 `Heartbeat.fromBuffer(wrapper.payload)` 解析；这是服务端对客户端心跳的响应，也应更新 `lastHeartbeatAt`。
- `CMD_DCM_CONTENT`：使用 `DcmContent.fromBuffer(wrapper.payload)` 解析并转换为 `PlayerJobItem`，然后调用 `PlayerTaskFile.updateTask(task)`。该方法按 `strJobItem` 去重，只有返回 `true` 时才表示新任务已加入 `PlayerTaskFile.vTaskQueue`；禁止直接向队列 `add`，也禁止只比较对象引用。
- `CMD_AH_SENDER` -> `AhSender`、`CMD_AH_MESSAGE` -> `MessageInfo`、`CMD_EVENT_MESSAGE` -> `DcmEventInfo`、`CMD_PLAYER_STATUS` -> `PlayerStatus`、`CMD_TRANSFER_STATUS` -> `TransferStatus`：使用对应的 `fromBuffer` 解析后交给业务 handler。
- `CMD_REQUEST_SYNC_TIME`、`CMD_REGISTER_UPDATE`、`CMD_REQUEST_DCM_CONTENT`、`CMD_REGISTER`、`CMD_RESET_TASKS`、`CMD_RESET_SETTINGS`、`CMD_RESET_TRANSFER`、`CMD_WEATHER`、`CMD_CONTENT_LIST`、`CMD_MONITOR`、`CMD_RESET_DCM_PLAYER`、`CMD_RESET_HOST`、`CMD_SMS_CONTROL`、`CMD_SHUTDOWN`、`CMD_UNIQUE_NAME`、`CMD_CONNECTION`、`CMD_LIGHT_BOX`、`CMD_REFRESH`、`CMD_DISK_CLEAN`：协议文件当前未为这些命令定义独立 payload 类型；保留显式分支，按服务端约定处理原始 payload，并记录命令名。
- `CMD_UNKNOWN` 和无法识别的枚举值：记录并忽略。

`CMD_DCM_CONTENT` 到 `PlayerJobItem` 的映射至少应保留：`task` -> `strJobItem`（用于去重；为空时必须按项目协议拒绝或生成明确的唯一标识）、`filePath` -> 文件/任务业务字段、`ftpTime` -> `strFtpTime`、`timeout` -> `strTimeOuts`、`startFtpTime` -> `strStartFtpTime`、`ftpContent` -> `dwSyncContent`、`period` -> `nSyncPeriod`、`retries` -> `nRetries`、`immediate` -> 立即任务类型/标志、`validity` -> `dtValidity`。`pid`、`allContent`、`includeToday` 等字段也不得静默丢弃，应按现有任务模型或 `strOtherInfo` 的项目约定保存。映射规则应集中在转换函数中，并用单元测试覆盖。

## 心跳保活

客户端至少维护心跳 Timer 和两个时间状态：

- 每 30 秒发送 `CMD_HEARTBEAT`，payload 是 `Heartbeat(playerId: playerId, status: status)`，`protocolId` 使用 `PROTOCOL_QC`。
- 服务端回复 `command == CMD_HEARTBEAT` 时解析其 `Heartbeat` payload，并更新 `lastHeartbeatAt`。
- 连续 90 秒未收到服务端 `CMD_HEARTBEAT` 响应，主动关闭当前 channel 并进入重连流程。
- `timestamp` 使用 `Int64(DateTime.now().millisecondsSinceEpoch)`；不要把时间戳塞进 payload 或依赖本地 ping/pong 文本协议。
- Timer 回调必须检查当前 channel、连接状态和 disposed 标志，避免旧连接的 Timer 操作新连接。

推荐的协议常量：

```dart
static const heartbeatInterval = Duration(seconds: 30);
static const heartbeatResponseTimeout = Duration(seconds: 90);
static const serverIdleTimeout = Duration(seconds: 120);
```

## 请求与响应匹配

- `MessageWrapper` 没有通用 `reqId` 字段，因此不要凭空添加 JSON `reqId` 或要求所有命令做请求响应匹配。
- 只有某个具体 Protobuf payload 明确定义请求 ID 时，才按该 payload 的字段建立 pending map；匹配逻辑必须使用对应命令和 ID，不能把 payload 当 JSON 解析。
- 心跳使用 `CMD_HEARTBEAT` 响应和 `lastHeartbeatAt` 做连接存活判断，不使用请求 ID。
- 连接异常、主动断开、重连开始或 `dispose()` 时，必须以明确异常完成并清空所有 pending 请求，不能留下永不完成的 Future。
- 没有匹配请求的业务消息应进入按命令分发的通知流；未知命令应记录并忽略。

## 指数退避重连

重连只允许由当前连接实例触发，并且必须防止重复调度。推荐公式：

```text
baseDelay = min(maxDelay, initialDelay * 2^attempt)
delay = baseDelay + random(0, jitter)
```

建议默认值：初始 1 秒，最大 60 秒，抖动 0 到 1 秒；连接成功后将 attempt 清零。连接失败、channel `onDone`、`onError` 和心跳响应超时都进入同一个重连入口。

要求：

- `disconnect()` 和 `dispose()` 设置 stopped/disposed 标志，取消已排队的重连，不能在关闭后自动恢复。
- 连接中或已有重连 Timer 时，`connect()` 应幂等返回，不得创建第二条连接。
- 每次新连接绑定唯一 generation/channel 引用；旧 channel 的回调不能关闭或重连新 channel。
- token、URL 或配置发生变化时，先关闭旧连接，再使用新配置建立连接。
- 是否限制最大重连次数由参数决定；达到上限后发布永久失败状态并停止自动重连。

## 生命周期绑定

Flutter UI 场景推荐由 `State` 实现 `WidgetsBindingObserver`：

- `initState()` 中注册 observer 并启动连接。
- 收到 `AppLifecycleState.paused`、`inactive` 或项目定义的后台状态时，调用服务 `disconnect(reconnect: false)`。
- 收到 `resumed` 时调用 `connect()`，重新执行鉴权和心跳初始化。
- `dispose()` 中移除 observer，并调用服务 `dispose()`。

如果连接属于全局应用服务，使用集中式生命周期监听器，但仍必须提供显式 `dispose()`；不要让 Widget 直接操作底层 channel。后台 isolate 不能直接复用 UI isolate 的 channel，应在所属 isolate 内独立管理连接。

## 推荐类结构

```dart
class CmsWebSocketService {
  CmsWebSocketService({WebSocketChannel Function(Uri uri)? channelFactory})
      : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final WebSocketChannel Function(Uri uri) _channelFactory;
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _reconnectTimer;
  final Map<String, Completer<MessageWrapper>> _pending = {};
  bool _disposed = false;
  bool _stopped = true;
  int _reconnectAttempt = 0;
  int _generation = 0;
  DateTime? _lastHeartbeatAt;

  Future<void> connect() async {
    // Build URI from AppGlobal.cmsUrl/AppGlobal.cmsToken, connect once,
    // listen to the channel, then start heartbeat timers.
  }

  Future<void> disconnect({bool reconnect = false}) async {
    // Cancel timers/subscription, complete pending requests, and close channel.
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
  }
}
```

实际实现可以使用 `StreamController<MessageWrapper>.broadcast()` 发布未消费的业务消息和状态，但必须在 `dispose()` 中关闭 controller。`WebSocketChannel.ready` 应在发送前等待，以便连接失败能进入统一错误流程；对兼容旧版 `web_socket_channel` 的代码，遵循项目当前依赖版本 API。

## 鉴权与安全

- WebSocket 握手不能依赖自定义 HTTP Header；优先使用 `?token=<encoded-token>`。
- 若服务端要求首条消息鉴权，则连接建立后第一条消息必须发送约定格式，并在鉴权成功前禁止发送业务消息。
- 日志中禁止输出完整 token、带 token 的 URI 或完整业务敏感数据；使用脱敏后的 host/path 和请求 id。
- `cmsUrl` 为空、token 为空或 scheme 不是 `http/https/ws/wss` 时，在连接前抛出可识别配置异常，不要启动无效重连循环。
- 不要把 token 写入持久化日志、异常文本或测试快照。

## 测试要求

至少覆盖以下行为：

1. `http` 转 `ws`、`https` 转 `wss`，路径只追加一个 `/ws`，token 正确 URL 编码。
2. `MessageWrapper` 和 `Heartbeat` 的 Protobuf 编解码，二进制帧能够被正确解析。
3. 发送的心跳 command、protocolId、playerId、status 和 timestamp 正确；收到 `CMD_HEARTBEAT` 会更新时间，90 秒无响应会关闭并触发一次重连。
4. 每个 `CommandType` 都能进入对应分支；`CMD_DCM_CONTENT` 能映射为 `PlayerJobItem`，相同 `strJobItem` 不会重复加入 `vTaskQueue`。
5. 网络错误、`onDone` 和发送失败使用同一指数退避策略，且成功连接后重置 attempt。
6. `disconnect()`、Widget 后台、`dispose()` 会取消 Timer、关闭 channel、完成 pending Future，并且不会再次重连。
7. 使用注入的 `channelFactory`/fake channel 测试，不连接真实 CMS。

## 何时使用

- 需要在 DCM Flutter 客户端连接 `AppGlobal.cmsUrl + '/ws'` 时
- 需要实现 `CMD_HEARTBEAT` 心跳、90 秒断线检测或 120 秒服务端空闲约束时
- 需要 WebSocket 断线指数退避、Protobuf 命令分发或业务消息流时
- 需要把连接绑定到 Widget dispose 或 Flutter 应用前后台生命周期时
- 需要通过 `AppGlobal.cmsToken` 进行 WebSocket URL query 鉴权时

## 常见错误

- 每次发消息创建新的 `WebSocketChannel`，导致连接泄漏和心跳失效。
- 只依赖 TCP/WebSocket `onDone`，没有实现应用层 `CMD_HEARTBEAT`。
- 把 Protobuf payload 当 JSON 解码，或直接把二进制帧转换为字符串。
- 收到 `CMD_DCM_CONTENT` 后直接向 `vTaskQueue` 添加任务，绕过 `PlayerTaskFile.updateTask` 的 `strJobItem` 去重。
- 发生错误后立刻无限重连，没有指数退避、抖动和重复调度保护。
- 只关闭 channel，不取消 Timer、subscription 或 pending Completer。
- 在 `dispose()` 后仍允许旧回调调度重连。
- 把 token 放在日志、异常或未编码的 URL 中。
- 使用 `AppGlobal.cmsUrl + '/ws'` 时未处理尾部斜杠或 `http/https` 到 `ws/wss` 的转换。
