# opentui-moonbit-ffi

用 [MoonBit](https://www.moonbitlang.com) 的 C ABI FFI 直接驱动
[OpenTUI](https://opentui.com/docs/) 原生渲染器，全程无 JavaScript 运行时。
包含两个示例与一个移植的按键绑定库：

- **hello**：对应官方文档 *Native rendering → C* 指南。构建
  `root → box → label` 场景树，渲染 `Hello` 写入 `hello.ansi`，再把同一棵树
  的文本改为 `Ready` 渲染第二帧（保留场景模型：改属性，不重建树），得到
  `ready.ansi`。
- **keymap-demo**：移植 keymap-demo 的核心理念，交互式 TUI。终端 raw mode
  + `ot_session_input_feed` 解析按键 + keymap dispatch + 差量渲染，j/k 移动、
  space 切换、`g g` 序列跳顶、`G` 跳底、q 退出。
- **keymap 包**：`@opentui/keymap` 核心的 MoonBit 移植（见下）。

```
┌──────────┐        ┌──────────┐
│Hello     │   →    │Ready     │
└──────────┘        └──────────┘
```

## 目录结构

目录布局对齐 OpenTUI 仓库的 packages 结构：

```
├── packages/
│   ├── core/                   # OpenTUI 原生渲染核心（ot_* C ABI）的绑定包
│   │   │                       # （import 别名 @core，对应 @opentui/core 的位置）
│   │   ├── types.mbt           # C 结构体声明（含布局兼容性注释）
│   │   ├── consts.mbt          # opentui.h 常量
│   │   ├── ffi.mbt             # extern "C" 原始绑定
│   │   ├── api.mbt             # 底层 API：Result 错误处理、记录头填充、颜色打包
│   │   ├── color.mbt           # TS 风格颜色字符串解析（#rrggbb/transparent…）
│   │   ├── ui_style.mbt        # StyleBuilder：ot_scene_flush 布局属性记录
│   │   ├── ui_node.mbt         # TS 兼容层：Renderable/Box/Text（new_box/new_text）
│   │   ├── ui_renderer.mbt     # TS 兼容层：Renderer（create/root/add/render/on_key/run）
│   │   ├── ui_terminal.mbt     # 终端 raw mode、stdin、输入事件→KeyStroke
│   │   └── ffi_test.mbt        # 纯 MoonBit 侧单元测试
│   ├── keymap/                 # @opentui/keymap 核心的 MoonBit 移植
│   │   ├── keys.mbt            # stroke 解析（"ctrl+shift+a"）与规范显示
│   │   ├── keymap.mbt          # 绑定注册、序列匹配、命令 dispatch
│   │   └── keymap_test.mbt     # dispatch 语义单元测试
│   └── examples/               # 可执行示例（每例一个子包，均为 TS 兼容层映射）
│       ├── hello/              # box + label，输出 .ansi（对应 C 指南，底层 API）
│       ├── keymap-demo/        # 交互式 TUI（keymap 驱动的选中列表）
│       ├── simple-layout/      # flex 四种布局切换（1-4 键）
│       ├── relative-positioning/ # absolute 定位方块移动（方向键）
│       ├── nested-zindex/      # z-index 叠放轮转（z 键）
│       ├── opacity/            # 四层透明度切换（1-4 键）
│       ├── text-wrap/          # 换行模式 none/char/word（w 键）
│       └── text-truncation/    # 截断开关（t 键）
├── scripts/fetch-opentui.sh    # 克隆并构建 OpenTUI 原生库
└── vendor/dist/<target>/       # opentui.h + libopentui（git 忽略，脚本生成）
```

与上游的对应关系：`packages/core` 绑定的是 OpenTUI 原生渲染器的
`ot_*` C ABI（即 packages/native 的产物），不是上游 TypeScript 层的
`@opentui/core`（Renderable/CliRenderer）；`packages/keymap` 与
`packages/examples` 的角色与上游一致。

## 快速开始

依赖：`moon`（MoonBit 工具链）、`bun`、`zig 0.16.x`（OpenTUI 构建锁定该版本，
macOS 可 `brew install zig@0.16`）、C 编译器。

```bash
# 1. 获取并构建 libopentui（约 3-5 分钟）
scripts/fetch-opentui.sh

# 2. 运行示例
moon run cmd/main --release          # hello：渲染两帧到 .ansi 文件
moon run cmd/keymap-demo --release   # 交互式 TUI（需要真实终端）

# 3. 测试与格式化
moon test --target native
moon fmt
```

## core 的 TS 兼容层

`packages/core` 分两层：底层是 `ot_*` C ABI 绑定（types/consts/ffi/api.mbt），
上层是与 `@opentui/core` API 对齐的 TS 兼容层（ui_*.mbt + color.mbt）。
移植 examples 时按 TS 代码直译即可：

```moonbit
let renderer = @core.Renderer::create(background="#1a1a2e")
// new BoxRenderable(renderer, { width: 42, backgroundColor: "#16213e", border: true })
let header = @core.new_box(renderer, width="42", background="#16213e", border=true)
// new TextRenderable(renderer, { content: "...", fg: "#e94560" })
header.add(@core.new_text(renderer, content="...", fg="#e94560", attributes="bold"))
renderer.root().add(header)
renderer.on_key(fn(stroke) { ... renderer.render() })
renderer.run()
```

- 属性取值用 TS 风格字符串：`"42"`（单元格）、`"50%"`、`"auto"`；
  颜色 `#rrggbb` / `#rgba` / `transparent` / 少量命名色；
  枚举 `"row"` / `"center"` / `"space-between"` / `"absolute"` 等。
- setter 立即提交：布局属性走 `ot_scene_flush` 属性记录流，绘制属性走
  paint 记录整体替换（内部缓存全量重建），文本走 text options。
- `Renderable::update_style(fn(b, h) { ... })` 可把多条布局变更合并为
  一次 flush。
- 解析失败按默认值处理（lossy），保证 UI 不因拼写错误崩溃。

## keymap 包（@opentui/keymap 核心移植）

移植覆盖原包（packages/keymap/src）的核心语义：

- 绑定串解析：`"j"`、`"ctrl+c"`、空格分隔序列 `"g g"`；修饰符
  ctrl/shift/meta/alt/option/super/cmd/hyper 顺序无关；单字符大写是
  `shift+小写` 语法糖（`"G"` ≡ `"shift+g"`）；`return` 归一为 `enter`。
- dispatch 决策（对应 dispatch-decisions.ts 的 sync 路径）：`run-exact`
  优先于 `continue-sequence`；不匹配时清除 pending 并把当前键作为新
  序列首键重试；Escape 可显式清除 pending。
- 命令注册 `km.on(command, handler)` 与 `binding_help()`（帮助栏）。

未移植：layer 条件系统、sequence pattern（`<any>` 捕获）、pending
超时（deferred disambiguation）、binding parser/token 扩展机制。

```moonbit
let km = @keymap.Keymap::new()
km.register([
  @keymap.Binding::make("j", "next", description="Next"),
  @keymap.Binding::make("g g", "top", description="Jump to first"),
])
km.on("next", fn() { ... })
match km.handle_key(@keymap.KeyStroke::make("g")) {
  @keymap.Ran(cmd) => ...      // 命令已执行
  @keymap.Pending(parts) => ... // 序列进行中
  @keymap.Cleared(_) => ...     // 序列被清除
  @keymap.Ignored => ...        // 无匹配
}
```

在真实终端里预览两帧（VT 兼容终端，至少 40 列 × 6 行）：

```bash
(
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf '%s\n' 'Run this preview in a terminal.' >&2
    exit 1
  fi
  trap 'printf "\033[0m\033[?25h\033[?1049l"' EXIT
  trap 'exit 130' INT
  printf '\033[?1049h\033[2J'
  cat hello.ansi || exit 1
  printf '\033[5;1HEnter: show Ready'
  IFS= read -r answer || exit 1
  cat ready.ansi || exit 1
  printf '\033[5;1H\033[KEnter: return to shell'
  IFS= read -r answer
)
```

## 构建配置说明

`cmd/main/moon.pkg` 通过 `cc-link-flags` 链接动态库：

- `-Lvendor/dist/aarch64-macos`：构建时的链接搜索路径（相对项目根）。
- `-Wl,-rpath,@executable_path/../../../../../../vendor/dist/aarch64-macos`：
  运行时搜索路径。moon 把可执行文件放在
  `_build/native/<profile>/build/cmd/main/` 下，六层 `..` 回到项目根。

链接 `libopentui.a` 静态库时还需要平台与 C++ 运行时库（见 OpenTUI 文档
*Build for another target*）。

## MoonBit ↔ OpenTUI C ABI 映射规则

以下规则均在 MoonBit `0.1.20261020`（debug = 新 native/LLVM 后端，
release = C 后端）下用探针程序逐字段验证过，两条后端行为一致。
`ffi/types.mbt` 的注释即按此展开。

### 基本类型

| C（opentui.h）              | MoonBit            |
| --------------------------- | ------------------ |
| `int32_t` / `uint32_t`      | `Int32` / `UInt32` |
| `uint64_t`                  | `UInt64`           |
| `float` / `double`          | `Float` / `Double` |
| `uint8_t *`                 | `Bytes` / `FixedArray[Byte]` |
| `uint16_t *`                | `FixedArray[UInt16]` |
| `void *`（不透明指针）      | external type 或 `UInt64` 别名 |
| `ot_status`（int32 枚举）   | `Int32`            |

### struct

- MoonBit `struct` 按声明顺序、按 C 对齐规则展开为普通 C struct；
  FFI 传参/返回时传指针，指向字段数据区，**没有对象头**。
- **陷阱 1：`UInt16` 字段按 4 字节传递**。C 侧 `uint16_t[4]` 数组字段
  用两个 `UInt32` 按小端打包（`pack_u16x2`），不用 `UInt16` 字段。
- **陷阱 2：嵌套 `struct` 字段按指针展开**，与 C 的值内联不一致。
  C 侧内联子结构（如 `ot_handle`）一律扁平化为标量字段。
- **陷阱 3：标量数组不是 struct 数组**。`FixedArray[SomeStruct]` 的
  元素是 GC 对象指针（C 视角 `Struct**`），不能当作连续 struct 内存
  交给 C。连续 struct 缓冲用 `Bytes` / `FixedArray[Byte]` 手动打包。
- `FixedArray[标量]`（`Byte`/`UInt16`/`UInt32`…）元素内联存储，
  映射 `T*`，可安全作为 out 缓冲。

### out 参数

- out 结构体参数直接传 struct 对象：指针指向字段数据区，原生库写入
  等于覆盖字段，随后 MoonBit 直接读字段。字段全为标量，GC 安全。
- **陷阱 4：全标量不可变 struct 的构造会被 C 后端静态提升为单例**。
  `let out = Handle::zero()` 在两次调用中返回同一对象，out 槽互相
  覆盖。out 容器必须带 `mut` 字段（`HandleOut` 等），强制独立堆分配。
- 传给 C 之前把版本化记录的 `struct_size` / `abi_version` 填好 ——
  **out 记录自身也是版本化记录**（`ot_scene_paint` 会校验
  `out_frame` 的头，不填返回 `OT_INVALID_ARGUMENT`）。

### 其他

- FFI 指针参数需显式 `#borrow`（借用约定，被调方不持有对象）；
  同一函数多个参数写进一个 `#borrow(a, b, c)`。
- 颜色通道（`uint16_t[4]`）取值 **0..255**：低 8 位是 RGBA 字节，
  高 8 位是原生颜色元数据，应用代码必须传 0。
- **sizeof 含尾部补齐**：`ot_scene_text_options` 有效字段到 76 字节但
  `sizeof == 80`（double 对齐），版本化记录头必须填 `sizeof` 的值。
- 绑定函数时逐参数核对头文件：`ot_session_drain_stdout` 有第 4 个
  `out_written` 输出参数，漏写会静默错位。
- `ot_session_input_feed` 要求 `capacity >= OT_INPUT_EVENTS_MIN (4)` 且
  `payload_capacity >= OT_INPUT_PAYLOAD_BYTES_MIN (4384)`；records 用
  连续 32 字节/条的字节缓冲 + 小端解析（陷阱 3 的实例）。
- 公开节点号（`num`）由应用自选，不能为 0；首个节点必须是
  `OT_SCENE_ROOT`。

## 绑定范围

已绑定示例所需的核心面：Context / Session 生命周期、渲染器附着、
场景节点创建与挂载、绘制属性与文本（含 `ot_scene_set_text_options`
前景/背景/属性/对齐）、`ot_scene_paint` / `ot_scene_frame_commit`、
输出队列 `read_output` / `complete_output` / `drain_stdout`，以及
交互式终端全流程：`setup_terminal`、`pump`、`get_terminal_state`、
`input_feed`（终端输入转 `ot_input_event`）、`close` 优雅恢复。
keymap-demo 另含 libc FFI：termios raw mode（不透明字节缓冲，整体
保存/恢复 + `cfmakeraw`）、`read` stdin、`ioctl` 窗口尺寸、
`clock_gettime` 单调纳秒时钟。

尚未绑定（`opentui.h` 有 3000+ 行声明，按需扩充 `ffi/ffi.mbt` 即可）：
帧步进与绘制钩子（`ot_scene_frame_step_with_geometry`）、属性流式更新
（`ot_scene_flush`）、编辑器节点、内嵌终端、Kitty 图片协议、鼠标事件
消费（解析已支持，事件已从 `input_feed` 返回）。

## 已知限制

- 原生库按主机架构构建；跨目标参考 `fetch-opentui.sh` 的 target 映射
  与 OpenTUI 的 `-Dlibrary-target=` 参数。
- MoonBit 后端 FFI 行为以 `0.1.20261020` 验证为准；升级工具链后建议
  重跑 `moon test --target native` 与示例核对布局。
- `Context` 以 `UInt64` 承载（指针在 arm64/x86_64 调用约定中与
  `uint64_t` 一致）；这是绕过编译器两处 FFI 边界问题
  （debug 后端 link-core 崩溃、external 类型空值占位）的取舍。
- keymap-demo 不处理终端 resize（需重新 attach renderer）与窗口
  事件；pending 序列无超时（一直等待下一键或 Escape）。
