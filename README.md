# opentui-moonbit-ffi

用 [MoonBit](https://www.moonbitlang.com) 的 C ABI FFI 直接驱动
[OpenTUI](https://opentui.com/docs/) 原生渲染器，全程无 JavaScript 运行时。

对应 OpenTUI 官方文档的 *Native rendering → C* 指南：示例程序构建一棵
`root → box → label` 场景树，渲染 `Hello` 写入 `hello.ansi`，再把同一棵树的
文本改为 `Ready` 渲染第二帧（保留场景模型：改属性，不重建树），得到
`ready.ansi`。

```
┌──────────┐        ┌──────────┐
│Hello     │   →    │Ready     │
└──────────┘        └──────────┘
```

## 目录结构

```
├── ffi/                        # MoonBit FFI 绑定包
│   ├── types.mbt               # C 结构体声明（含布局兼容性注释）
│   ├── consts.mbt              # opentui.h 常量
│   ├── ffi.mbt                 # extern "C" 原始绑定
│   ├── api.mbt                 # 高层 API：Result 错误处理、记录头填充、颜色打包
│   └── ffi_test.mbt            # 纯 MoonBit 侧单元测试
├── cmd/main/                   # 可执行示例（box + label，输出 .ansi）
├── scripts/fetch-opentui.sh    # 克隆并构建 OpenTUI 原生库
└── vendor/dist/<target>/       # opentui.h + libopentui（git 忽略，脚本生成）
```

## 快速开始

依赖：`moon`（MoonBit 工具链）、`bun`、`zig 0.16.x`（OpenTUI 构建锁定该版本，
macOS 可 `brew install zig@0.16`）、C 编译器。

```bash
# 1. 获取并构建 libopentui（约 3-5 分钟）
scripts/fetch-opentui.sh

# 2. 运行示例
moon run cmd/main --release
# 或开发模式
moon run cmd/main

# 3. 测试与格式化
moon test --target native
moon fmt
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
- 公开节点号（`num`）由应用自选，不能为 0；首个节点必须是
  `OT_SCENE_ROOT`。

## 绑定范围

已绑定示例所需的核心面：Context / Session 生命周期、渲染器附着、
场景节点创建与挂载、绘制属性与文本、`ot_scene_paint` /
`ot_scene_frame_commit`、输出队列 `read_output` / `complete_output`。

尚未绑定（`opentui.h` 有 3000+ 行声明，按需扩充 `ffi/ffi.mbt` 即可）：
帧步进与绘制钩子（`ot_scene_frame_step_with_geometry`）、属性流式更新
（`ot_scene_flush`）、编辑器节点、内嵌终端、Kitty 图片协议、终端
setup/pump/恢复等。交互式 TUI 需要实现 *Host I/O and time* 描述的
泵循环与单调时钟，示例未包含。

## 已知限制

- 原生库按主机架构构建；跨目标参考 `fetch-opentui.sh` 的 target 映射
  与 OpenTUI 的 `-Dlibrary-target=` 参数。
- MoonBit 后端 FFI 行为以 `0.1.20261020` 验证为准；升级工具链后建议
  重跑 `moon test --target native` 与示例核对布局。
- `Context` 以 `UInt64` 承载（指针在 arm64/x86_64 调用约定中与
  `uint64_t` 一致）；这是绕过编译器两处 FFI 边界问题
  （debug 后端 link-core 崩溃、external 类型空值占位）的取舍。
