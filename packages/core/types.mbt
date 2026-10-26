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

///|
/// ot_styled_text_chunk（48 字节）由 ui_extra.mbt 的 set_styled_chunks
/// 直接编码进字节缓冲：struct_size, abi, byte_count, flags,
/// fg[4], bg[4], attributes, reserved, link_offset, link_byte_count。

///|
/// C: ot_scene_slider_options，sizeof == 64。orientation: 0=horizontal 1=vertical。
priv struct SliderOptions {
  struct_size : UInt32
  abi_version : UInt32
  orientation : UInt32
  reserved : UInt32
  min : Double
  max : Double
  value : Double
  viewport_size : Double
  foreground01 : UInt32
  foreground23 : UInt32
  background01 : UInt32
  background23 : UInt32
}

///|
/// StyledChunk / SliderOptions 的 out 容器不适用（它们是输入记录，
/// 由字节缓冲编码），这里提供解析结果不需要；输入记录用 builder 编码。

///|
/// C: ot_session_control_options，sizeof == 20。kind 取 OT_CONTROL_*，
/// argument 仅 MOUSE 用（0/1/2 = 禁用/拖动/全移动），其余必须为 0。
priv struct ControlOptions {
  struct_size : UInt32
  abi_version : UInt32
  kind : UInt32
  argument : UInt32
  reserved : UInt32
}

///|
/// C: ot_buffer_options，sizeof == 24。width_method 取 OT_WIDTH_METHOD_*，
/// flags 仅 OT_BUFFER_RESPECT_ALPHA。width*height 受 render_cells_max 约束。
priv struct BufferOptions {
  struct_size : UInt32
  abi_version : UInt32
  width : UInt32
  height : UInt32
  width_method : UInt32
  flags : UInt32
}

///|
/// C: ot_scene_hooks，sizeof == 40。generation 非 0 且变更时必须递增；
/// initial_* 仅在首次布局前生效。
priv struct SceneHooks {
  struct_size : UInt32
  abi_version : UInt32
  flags : UInt32
  reserved : UInt32
  generation : UInt64
  initial_width : Double
  initial_height : Double
}

///|
/// C: ot_scene_frame_options，sizeof == 36（全 4 字节对齐成员，无尾部补齐）。
priv struct SceneFrameOptions {
  struct_size : UInt32
  abi_version : UInt32
  background01 : UInt32
  background23 : UInt32
  use_mouse : UInt32
  excluded_hit_num : UInt32
  max_layout_rounds : UInt32
  max_host_requests : UInt32
  preserve_unwritten : UInt32
}

// ot_buffer_draw_* 记录（见下）。注意：MoonBit 嵌套 struct 字段按指针
// 展开，必须扁平化声明（布局规则见文件头注释）。

///|
/// C: ot_buffer_draw_clear，sizeof == 24。前 4 字段是 ot_buffer_draw_header
/// （struct_size 是完整记录大小；flags 仅 TEXT 用 HAS_BACKGROUND）。
priv struct BufferDrawClear {
  struct_size : UInt32
  abi_version : UInt32
  operation : UInt32
  flags : UInt32
  background01 : UInt32
  background23 : UInt32
}

///|
/// C: ot_buffer_draw_fill，sizeof == 40。
priv struct BufferDrawFill {
  struct_size : UInt32
  abi_version : UInt32
  operation : UInt32
  flags : UInt32
  x : Int32
  y : Int32
  width : UInt32
  height : UInt32
  background01 : UInt32
  background23 : UInt32
}

///|
/// C: ot_buffer_draw_text_record，sizeof == 44。
priv struct BufferDrawTextRecord {
  struct_size : UInt32
  abi_version : UInt32
  operation : UInt32
  flags : UInt32
  x : Int32
  y : Int32
  attributes : UInt32
  foreground01 : UInt32
  foreground23 : UInt32
  background01 : UInt32
  background23 : UInt32
}

///|
/// C: ot_buffer_draw_cell，sizeof == 48。
priv struct BufferDrawCell {
  struct_size : UInt32
  abi_version : UInt32
  operation : UInt32
  flags : UInt32
  x : Int32
  y : Int32
  character : UInt32
  attributes : UInt32
  foreground01 : UInt32
  foreground23 : UInt32
  background01 : UInt32
  background23 : UInt32
}

///|
/// C: ot_scene_text_selection_options，sizeof == 56（全 4 字节对齐成员）。
/// anchor/focus 是相对节点原点的 cell 坐标；flags 决定 bg/fg 是否生效。
priv struct TextSelectionOptions {
  struct_size : UInt32
  abi_version : UInt32
  operation : UInt32
  behavior : UInt32
  anchor_x : Int32
  anchor_y : Int32
  focus_x : Int32
  focus_y : Int32
  flags : UInt32
  reserved : UInt32
  background01 : UInt32
  background23 : UInt32
  foreground01 : UInt32
  foreground23 : UInt32
}

///|
/// C: ot_scene_layout，sizeof == 48（layout 头 + 6 个 f32 + 2 个 f64）。
/// out 参数：读取节点几何（OT_LAYOUT_PUBLIC/PAINT）。
priv struct SceneLayout {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut left : Float
  mut top : Float
  mut right : Float
  mut bottom : Float
  mut width : Float
  mut height : Float
  mut screen_x : Double
  mut screen_y : Double
}

///|
/// C: ot_edit_buffer_options，sizeof == 16。
priv struct EditBufferOptions {
  struct_size : UInt32
  abi_version : UInt32
  width_method : UInt32
  reserved : UInt32
}

///|
/// C: ot_edit_buffer_info，sizeof == 48（头8 + u64 + 8×u32）。out 记录。
priv struct EditBufferInfo {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut content_epoch : UInt64
  mut byte_count : UInt32
  mut line_count : UInt32
  mut cursor_row : UInt32
  mut cursor_col : UInt32
  mut cursor_offset : UInt32
  mut can_undo : UInt32
  mut can_redo : UInt32
  mut tab_width : UInt32
}

///|
/// C: ot_editor_viewport，sizeof == 24。
priv struct EditorViewport {
  struct_size : UInt32
  abi_version : UInt32
  x : UInt32
  y : UInt32
  width : UInt32
  height : UInt32
}

///|
/// C: ot_editor_view_info，sizeof == 32（8×u32）。out 记录。
priv struct EditorViewInfo {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut virtual_line_count : UInt32
  mut total_virtual_line_count : UInt32
  mut selection_present : UInt32
  mut selection_start : UInt32
  mut selection_end : UInt32
  mut selection_occupancy : UInt32
}

///|
/// C: ot_edit_position，sizeof == 24（edit buffer 位置；valid=0 表示无效）。
priv struct EditPosition {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut valid : UInt32
  mut row : UInt32
  mut col : UInt32
  mut offset : UInt32
}

///|
/// C: ot_editor_position，sizeof == 28。out 记录。
priv struct EditorPosition {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut visual_row : UInt32
  mut visual_col : UInt32
  mut logical_row : UInt32
  mut logical_col : UInt32
  mut offset : UInt32
}

///|
/// C: ot_editor_selection，sizeof == 72（14×u32 + 2×u16[4]，无补齐）。
priv struct EditorSelection {
  struct_size : UInt32
  abi_version : UInt32
  operation : UInt32
  behavior : UInt32
  start : UInt32
  end : UInt32
  anchor_x : Int32
  anchor_y : Int32
  focus_x : Int32
  focus_y : Int32
  update_cursor : UInt32
  follow_cursor : UInt32
  flags : UInt32
  reserved : UInt32
  foreground01 : UInt32
  foreground23 : UInt32
  background01 : UInt32
  background23 : UInt32
}

///|
/// C: ot_scene_editor_options，sizeof == 40（8 + 4×u32 + color 8 + 2×u32 + 补齐）。
priv struct SceneEditorOptions {
  struct_size : UInt32
  abi_version : UInt32
  show_cursor : UInt32
  style : UInt32
  blinking : UInt32
  reserved : UInt32
  color01 : UInt32
  color23 : UInt32
  mouse_pointer : UInt32
  reserved2 : UInt32
}

///|
/// C: ot_edit_highlight，sizeof == 20。
priv struct EditHighlight {
  start : UInt32
  end : UInt32
  style_id : UInt32
  priority : UInt32
  ref_ : UInt32
}

///|
/// C: ot_text_buffer_info，sizeof == 40（头8 + u64 + 6×u32）。out 记录。
priv struct TextBufferInfo {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut content_epoch : UInt64
  mut byte_count : UInt32
  mut text_length : UInt32
  mut line_count : UInt32
  mut highlight_count : UInt32
  mut tab_width : UInt32
  mut reserved : UInt32
}

///|
/// 独立的 uint16_t[4] 颜色参数（set_tab_color 等）：8 字节尾随无补齐。
priv struct Rgba16 {
  c01 : UInt32
  c23 : UInt32
}

///|
/// C: ot_image_info，sizeof == 32（8×u32）。out 记录。
priv struct ImageInfo {
  mut width : UInt32
  mut height : UInt32
  mut source_width : UInt32
  mut source_height : UInt32
  mut format : UInt32
  mut color_status : UInt32
  mut orientation : UInt32
  mut has_alpha : UInt32
}

///|
/// C: ot_session_kitty_image_transport，sizeof == 32（8×u32）。out 记录。
priv struct KittyTransportStatus {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut requested : UInt32
  mut effective : UInt32
  mut file_state : UInt32
  mut fallback : UInt32
  mut pending_files : UInt32
  mut pending_bytes : UInt32
}

///|
/// C: ot_split_control，sizeof == 36（9×u32）。
priv struct SplitControl {
  struct_size : UInt32
  abi_version : UInt32
  command : UInt32
  arg0 : UInt32
  arg1 : UInt32
  arg2 : UInt32
  arg3 : UInt32
  arg4 : UInt32
  arg5 : UInt32
}

///|
/// C: ot_session_renderer_state，sizeof == 32（头8 + u64 + 2×u32）。out 记录。
priv struct RendererState {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut width : UInt32
  mut height : UInt32
  mut frame_count : UInt64
  mut frame_pending : UInt32
  mut reserved : UInt32
}

///|
/// C: ot_session_capabilities，sizeof == 144（12×u32 + term_name 64B + term_version 32B）。
/// 名字/版本按小端 u32 组返回，读取时解包。
priv struct SessionCaps {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut flags : UInt32
  mut width_method : UInt32
  mut multiplexer : UInt32
  mut image_protocol : UInt32
  mut osc52_support : UInt32
  mut kitty_keyboard_flags : UInt32
  mut term_name_len : UInt32
  mut term_version_len : UInt32
  mut term_from_xtversion : UInt32
  mut reserved : UInt32
  mut name_words : (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)
  mut version_words : (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)
}

///|
/// C: ot_embedded_terminal_options，sizeof == 24（6×u32）。
priv struct EmbeddedTerminalOptions {
  struct_size : UInt32
  abi_version : UInt32
  cols : UInt32
  rows : UInt32
  max_scrollback : UInt32
  reserved : UInt32
}

///|
/// C: ot_embedded_terminal_cursor，sizeof == 56（14×u32）。out 记录。
priv struct EmbeddedTerminalCursor {
  mut struct_size : UInt32
  mut abi_version : UInt32
  mut x : UInt32
  mut y : UInt32
  mut has_value : UInt32
  mut visible : UInt32
  mut blinking : UInt32
  mut wide_tail : UInt32
  mut style : UInt32
  mut color_has_value : UInt32
  mut color_r : UInt32
  mut color_g : UInt32
  mut color_b : UInt32
  mut reserved : UInt32
}
