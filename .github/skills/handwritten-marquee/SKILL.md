---
name: handwritten-marquee
summary: '基于 Flutter 底层动画系统手写可复用跑马灯，支持文字、图片和 HTML，以及多方向、多种循环模式和完整视觉参数。'
description: |
  Use this skill when implementing or refactoring a Flutter marquee, ticker, scrolling banner, or floating overlay.
  The implementation must use Flutter's lower-level animation primitives such as AnimationController,
  Animation<double>, Tween, CustomPainter, ClipRect, and/or Transform instead of relying on a marquee package
  to own the motion. It supports static content and animated content of text, images, or HTML; left, right,
  up, and down movement; infinite, ping-pong, slide, and seamless looping; speed, typography, colors,
  background, alignment, opacity, and an optional screen-top floating presentation.
  Prefer the existing project's architecture, WebView integration, localization, and test conventions.
arguments:
  - name: contentType
    description: '内容类型：text、image 或 html。'
    type: string
  - name: direction
    description: '滚动方向：left、right、up 或 down。'
    type: string
  - name: behavior
    description: '播放模式：static、infinite、pingPong、slide 或 seamless。'
    type: string
  - name: speed
    description: '滚动速度，建议使用 logical pixels per second，而不是把速度直接绑定到帧数。'
    type: number
  - name: font
    description: '字体配置，包括 size、family、weight、style、decoration 和 color。'
    type: object
  - name: background
    description: '背景配置，包括 color、image 和 opacity。'
    type: object
  - name: alignment
    description: '内容对齐方式：horizontal、vertical、或 Alignment。'
    type: object
  - name: opacity
    description: '整个跑马灯的透明度，范围 0.0 到 1.0。'
    type: number
  - name: floating
    description: '是否脱离普通布局浮动显示在屏幕上方，以及对应 Overlay/Stack 约束。'
    type: boolean
---

# 手写跑马灯 Skill

## 目标

生成一个可测试、可复用的 Flutter 跑马灯组件。组件应把内容、运动状态、渲染裁剪和浮动宿主分开，避免业务数据模型直接控制动画细节。默认优先兼容 Dart 3 / Flutter 项目的现有代码风格。

本技能的核心约束：

- 不把 `marqueer` 或其他跑马灯包作为运动引擎；可以参考现有行为，但位移必须由自己的 `AnimationController` 驱动。
- 所有速度都使用 logical pixels per second，动画时长根据内容尺寸和轨道尺寸计算，不能用固定时长掩盖不同屏幕尺寸。
- 跑马灯必须在 `dispose` 中释放 controller；配置或内容尺寸变化时要正确停止、重建或调整动画。
- 内容始终在 `ClipRect` 或等价裁剪区域内，不能溢出到相邻 UI。
- 先确认 `text`、`image`、`html` 三种内容的尺寸；HTML 内容使用项目已有 WebView 能力，不能把不可信 HTML 直接当 Flutter 文本渲染。
- 当 `BannerData.nTemplate == 9` 时，允许把 `strText` 解释为 RSS/Atom URL；网络读取必须异步、定时刷新，并在失败时保留上一次成功内容。

## 推荐 API

按项目命名习惯生成类似下面的公开模型，不要把所有参数散落在 Widget 构造函数中：

```dart
enum MarqueeContentType { text, image, html }
enum MarqueeDirection { left, right, up, down }
enum MarqueeBehavior { static, infinite, pingPong, slide, seamless }

class MarqueeStyle {
  const MarqueeStyle({
    this.textStyle,
    this.backgroundColor,
    this.backgroundImage,
    this.alignment = Alignment.center,
    this.opacity = 1,
  });

  final TextStyle? textStyle;
  final Color? backgroundColor;
  final ImageProvider<Object>? backgroundImage;
  final Alignment alignment;
  final double opacity;
}

class HandwrittenMarquee extends StatefulWidget {
  const HandwrittenMarquee({
    super.key,
    required this.child,
    this.direction = MarqueeDirection.left,
    this.behavior = MarqueeBehavior.infinite,
    this.speed = 60,
    this.style = const MarqueeStyle(),
    this.floating = false,
  });

  final Widget child;
  final MarqueeDirection direction;
  final MarqueeBehavior behavior;
  final double speed;
  final MarqueeStyle style;
  final bool floating;

  @override
  State<HandwrittenMarquee> createState() => _HandwrittenMarqueeState();
}
```

实际实现可以采用 `child`、内容工厂或统一的 `MarqueeContent` 类型，但必须保留同样的职责边界：内容负责绘制，运动层负责位移，宿主负责尺寸和浮动位置。

## 实现流程

1. 读取并规范化参数。
   - 将速度限制为非负值；将透明度限制在 `0.0..1.0`。
   - 明确 `static` 不创建或不启动动画。
   - 明确方向轴：left/right 使用水平轴，up/down 使用垂直轴。
2. 测量 viewport 和内容尺寸。
   - 文本使用 `TextPainter` 或实际布局后的尺寸。
   - 图片使用已解析的宽高和 `BoxFit`。
   - HTML 使用 WebView 的受限 viewport 或已知内容尺寸；加载完成前显示稳定占位尺寸，避免动画轨道抖动。
3. 创建运动轨道。
   - 静态模式使用 `Align`/`FittedBox`/普通布局。
   - 非静态模式使用 `AnimationController.unbounded` 或有界 controller 加 `Tween<double>`。
   - 通过 `AnimatedBuilder`、`Transform.translate` 或 `CustomPainter` 应用位移；不要在 ticker 回调中直接 `setState` 每帧重建整个页面。
4. 根据方向计算起点、终点和有效距离。
   - left：内容从 viewport 右侧进入并向左离开。
   - right：内容从 viewport 左侧进入并向右离开。
   - up：内容从底部进入并向上离开。
   - down：内容从顶部进入并向下离开。
   - `distance` 必须包含 viewport 尺寸与内容尺寸，避免首尾出现提前跳转。
5. 根据 `distance / speed` 计算 duration。
   - speed 为 0 时不要启动周期动画，降级为静态对齐。
   - duration 至少设置合理下限，防止极短内容造成高频重启。
6. 实现模式。
   - `infinite`：单内容离场后从另一侧重新进入；使用 `repeat` 或显式重置，确保重置发生在裁剪区域外。
   - `pingPong`：使用 `reverse: true`，往返结束时保持端点，不闪回起点。
   - `slide`：只播放一次，完成后停留在目标端点，并提供 `onCompleted`（若项目需要）。
   - `seamless`：至少复制两份内容，第二份紧跟第一份；在一份内容完整离场时无缝调整循环相位。内容宽度或高度变化时重新计算间距。
   - `static`：不做位移，仍支持字体、背景、对齐和透明度。
7. 应用视觉参数。
   - 使用 `DefaultTextStyle`/`TextStyle` 设置字体 family、size、weight、style、decoration、color。
   - 背景可使用 `ColoredBox`、`DecoratedBox` 或 `DecorationImage`。
   - 透明度只包裹跑马灯自身，避免误伤屏幕其他区域；优先使用 `Opacity` 或 `FadeTransition`，并说明其合成成本。
   - 对齐必须作用于 viewport 内的内容，而不是改变轨道起点的语义。
8. 支持浮动显示。
   - 默认组件保持普通布局行为。
   - 需要浮动时，由页面宿主使用 `Stack` + `Positioned` 或 `OverlayEntry` 提供 top/left/right/width/height 约束。
   - 不要在通用组件内部直接操作全局 Overlay，除非需求明确要求它管理插入和移除生命周期。
   - 浮动模式必须处理安全区、窗口尺寸变化、方向变化和重复插入；移除时释放 controller/WebView。
9. 支持 RSS 内容源。
  - 解析 RSS `item` 和 Atom `entry`，至少读取 `title`、`description`/`summary`/`content`、`link` 和发布时间。
  - 支持标题跑马灯，以及 `Title + Content` 页面；页面可以按固定秒数轮流切换。
  - 页面切换使用 `AnimatedSwitcher` 等明确的淡入、滑入或缩放效果；随机效果必须由状态控制，不能每帧随机。
  - RSS 更新使用独立 refresh timer，更新成功后重置或校正页面索引；更新失败显示错误状态但不要清空已有内容。
  - 所有 Timer、网络请求和 controller 必须在 `dispose` 中取消或释放，避免卸载页面后回调。

## HTML 内容

- 复用项目已有 `webview_flutter` 或 `flutter_inappwebview` 封装，不新增第二套 WebView 初始化路径。
- HTML 页面使用透明背景或显式背景色，并通过 viewport 元标签、禁用滚动和 CSS `overflow: hidden` 固定内容边界。
- HTML 运动优先由 Flutter 外层 `Transform.translate` 控制；只有 HTML 内部动画确实需要独立时间线时，才在页面内使用 CSS 动画，并明确暂停、销毁和安全限制。
- 禁止把任意远程脚本、导航或 JavaScript 注入当作默认能力。根据项目的 URL allowlist、资源加载和错误回调策略处理内容。
- WebView 加载、尺寸获取和动画启动应有清晰状态：loading、ready、error；加载失败不能让 ticker 持续空转。

## 与当前 DCM 项目的适配

- 当前项目有 `lib/widgets/scrolltext.dart` 和 `BannerData`；改造时优先保留现有 `ScrollText` 的外部输入和 XML 字段含义，把 `_getDirection`、`_getAlignment`、文字样式映射迁移到独立配置或纯函数。
- 当前项目已有 `webview_flutter`、`flutter_inappwebview` 和 `marqueer` 依赖。新实现应复用已有 WebView widget；`marqueer` 只能作为旧实现兼容参考，不应继续承担底层动画。
- 当前项目使用 `AppGlobal`、`Utils.fromRGB` 等现有颜色和配置工具时，应继续复用，不在跑马灯 Skill 中发明平行的颜色解析规则。
- 避免无关重构；先让文字模式工作，再接入图片、HTML和浮动宿主。

## 验证清单

至少覆盖以下行为：

- 静态文字四种对齐方式和字体属性正确。
- 四个方向的位移符号、起终点和裁剪正确。
- 速度改变会改变 duration，但不会改变方向或内容尺寸。
- `infinite` 不闪回，`pingPong` 不跳跃，`slide` 完成后停留，`seamless` 首尾没有可见空隙。
- 内容尺寸变化、窗口旋转、父约束变化后不会溢出或卡在旧轨道。
- `speed == 0`、空文本、加载失败 HTML、透明度边界值不会抛异常。
- Widget dispose 后 controller、Timer、AnimationStatusListener 和 WebView 不再产生回调。
- 浮动模式不会重复插入 Overlay，也不会覆盖安全区之外未预期的区域。

优先添加纯 Dart 单元测试覆盖：方向和模式到轨道参数的映射、duration 计算、透明度/速度规范化、起终点计算。再添加 Flutter widget test 覆盖裁剪、静态内容和 controller 生命周期；HTML/WebView 集成测试只在项目已有测试设备和能力时添加。

## 输出要求

使用此 Skill 生成代码时，输出应包含：

1. 变更的文件和接入点。
2. 运动模型的关键不变量：轴、起点、终点、距离、duration 和循环相位。
3. 内容类型的处理方式，尤其是 HTML 的加载和安全边界。
4. 需要添加或更新的测试，以及运行的最窄验证命令。
5. 若现有依赖或平台能力限制了某项功能，明确说明降级行为，而不是静默省略。
