// OpenTUI C ABI 类型绑定。
//
// 对应 vendor/dist/aarch64-macos/opentui.h（OT_CONTEXT_ABI_VERSION == 2）。
// MoonBit struct 会按声明顺序以 C 对齐规则展开为普通 C struct（FFI 传递时
// 传指针、无对象头），但要注意两条经验规则：
//
// 1. UInt16 字段在 FFI 中按 4 字节传递，不能用于匹配 C 的 uint16_t。
//    C 侧 uint16_t[4] 数组用两个 UInt32 按小端打包（见 pack_u16x2）。
// 2. 嵌套 struct 字段在 FFI 中按指针传递，与 C 的值内联不一致。
//    C 侧的 ot_handle 等内联子结构一律扁平化为标量字段。

///|
/// ot_context*，不透明句柄。以 64 位整数承载（arm64/x86_64 上指针与
/// uint64 的调用约定一致），0 表示空。刻意不导出，外部只能通过本包 API 使用。
pub type Context = UInt64

///|
/// C: ot_handle { uint64_t context_id; uint32_t slot; uint32_t generation; }
/// 全零为非法句柄。仅作为独立 FFI 参数（指针传递）使用；
/// 出现在其他 struct 内部时必须扁平化。
pub struct OtHandle {
  context_id : UInt64
  slot : UInt32
  generation : UInt32
}

///|
/// C: ot_context_options，sizeof == 32
pub struct ContextOptions {
  struct_size : UInt32
  abi_version : UInt32
  flags : UInt32
  object_capacity : UInt32
  render_cells_max : UInt32
  reserved0 : UInt32
  reserved1 : UInt32
  reserved2 : UInt32
}

///|
/// C: ot_session_options，sizeof == 32
/// （uint64_t max_bytes 前的 4 字节对齐填充由 C 对齐规则自动产生）
pub struct SessionOptions {
  struct_size : UInt32
  abi_version : UInt32
  chunk_size : UInt32
  span_capacity : UInt32
  max_bytes : UInt64
  control_capacity : UInt32
  reserved : UInt32
}

///|
/// C: ot_session_renderer_options，sizeof == 24
pub struct SessionRendererOptions {
  struct_size : UInt32
  abi_version : UInt32
  width : UInt32
  height : UInt32
  remote : UInt32
  reserved : UInt32
}

///|
/// C: ot_scene_paint_options，sizeof == 80
/// 颜色字段 uint16_t[4] 打包为两个 UInt32（小端：低 16 位是数组前两个元素）。
pub struct ScenePaintOptions {
  struct_size : UInt32
  abi_version : UInt32
  z_index : Int32
  opacity : Float
  translate_x : Double
  translate_y : Double
  border_sides : UInt32
  should_fill : UInt32
  background01 : UInt32
  background23 : UInt32
  border_color01 : UInt32
  border_color23 : UInt32
  border_style : UInt32
  focusable : UInt32
  focused_border_color01 : UInt32
  focused_border_color23 : UInt32
  reserved : UInt32
}

///|
/// C: ot_scene_frame_request，sizeof == 112
/// 三个 ot_handle 已扁平化；字段偏移与 C 布局逐字段一致。
pub struct SceneFrameRequest {
  struct_size : UInt32
  abi_version : UInt32
  session_context_id : UInt64
  session_slot : UInt32
  session_generation : UInt32
  root_context_id : UInt64
  root_slot : UInt32
  root_generation : UInt32
  node_context_id : UInt64
  node_slot : UInt32
  node_generation : UInt32
  frame_id : UInt64
  request_id : UInt64
  layout_epoch : UInt64
  hook_generation : UInt64
  kind : UInt32
  num : UInt32
  width : UInt32
  height : UInt32
  reserved0 : UInt32
  reserved1 : UInt32
}

///|
/// C: ot_output_ticket，sizeof == 32
/// 内嵌 ot_handle 已扁平化。
pub struct OutputTicket {
  session_context_id : UInt64
  session_slot : UInt32
  session_generation : UInt32
  request_id : UInt64
  byte_count : UInt32
  reserved : UInt32
}

///|
/// ot_context* 的可变 out 容器。带 mut 字段保证每次构造都是独立堆对象。
/// 包内私有：外部通过 create_context 拿到 Context 值即可。
priv struct ContextOut {
  mut ptr : Context
}

///|
/// out 参数的可变容器：带 mut 字段的 struct 每次构造都是独立堆对象，
/// 不会被编译器静态提升为单例（全标量不可变 struct 的构造会被提升，
/// 导致多个 out 槽共享同一对象、互相覆盖）。字段布局与对应记录一致，
/// 原生库直接向其字段区写入结果，再由 to_handle 等转换回不可变值。
pub struct HandleOut {
  mut context_id : UInt64
  mut slot : UInt32
  mut generation : UInt32
}

///|
pub struct FrameRequestOut {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut session_context_id : UInt64
  mut session_slot : UInt32
  mut session_generation : UInt32
  mut root_context_id : UInt64
  mut root_slot : UInt32
  mut root_generation : UInt32
  mut node_context_id : UInt64
  mut node_slot : UInt32
  mut node_generation : UInt32
  mut frame_id : UInt64
  mut request_id : UInt64
  mut layout_epoch : UInt64
  mut hook_generation : UInt64
  mut kind : UInt32
  mut num : UInt32
  mut width : UInt32
  mut height : UInt32
  mut reserved0 : UInt32
  mut reserved1 : UInt32
}

///|
pub struct TicketOut {
  mut session_context_id : UInt64
  mut session_slot : UInt32
  mut session_generation : UInt32
  mut request_id : UInt64
  mut byte_count : UInt32
  mut reserved : UInt32
}

///|
/// C: ot_session_terminal_options，sizeof == 16。
priv struct TerminalOptions {
  struct_size : UInt32
  abi_version : UInt32
  flags : UInt32
  kitty_keyboard_flags : UInt32
}

///|
/// C: ot_scene_text_options，sizeof == 80（尾部按 8 字节对齐补齐）。
/// 文本前景/背景/属性/对齐。TS 兼容层的选项结构见 ui_node.mbt。
struct SceneTextOptions {
  struct_size : UInt32
  abi_version : UInt32
  foreground01 : UInt32
  foreground23 : UInt32
  background01 : UInt32
  background23 : UInt32
  attributes : UInt32
  wrap_mode : UInt32
  truncate : UInt32
  first_line_offset : UInt32
  scroll_x : Double
  scroll_y : Double
  tab_indicator : UInt32
  tab_color_set : UInt32
  tab_color01 : UInt32
  tab_color23 : UInt32
  text_align : UInt32
}

///|
/// 解析后的输入事件（字段已从 ot_input_event 的小端字节展开；
/// u8/u16 字段零扩展为 UInt32）。公开给应用层使用。
pub struct InputEvent {
  kind : UInt32
  action : UInt32
  modifiers : UInt32
  flags : UInt32
  code : UInt32
  base_code : UInt32
  x : UInt32
  y : UInt32
  text : String
}

///|
priv struct InputDrainOut {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut consumed : UInt32
  mut count : UInt32
  mut payload_len : UInt32
  mut discarded : UInt32
  mut deadline_ns : UInt64
}

///|
priv struct PumpResultOut {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut status : UInt32
  mut reserved : UInt32
  mut deadline_ns : UInt64
}
