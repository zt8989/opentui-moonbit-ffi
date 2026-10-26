// OpenTUI C ABI 原始绑定。符号名与 opentui.h 中的声明一一对应。
//
// 所有指针参数标注 #borrow：被调方（原生库）只在调用期间借用，
// 不持有 MoonBit 对象；out 参数同样按借用处理（原生库向缓冲区写入结果）。

///|
#borrow(options, out_context)
extern "C" fn ot_context_create(
  options : ContextOptions,
  out_context : ContextOut,
) -> Int32 = "ot_context_create"

///|
extern "C" fn ot_context_destroy(context : Context) -> Int32 = "ot_context_destroy"

///|
// out_session 传 GC struct 对象：FFI 传参即指向字段数据区的指针，
// 原生库向其写入 16 字节等于直接覆盖 OtHandle 的三个标量字段。
// （不能用 FixedArray[OtHandle]：那是 GC 指针数组，C 侧会破坏 GC 堆。）
#borrow(options, out_session)
extern "C" fn ot_session_create(
  context : Context,
  options : SessionOptions,
  out_session : HandleOut,
) -> Int32 = "ot_session_create"

///|
#borrow(session, options)
extern "C" fn ot_session_attach_renderer(
  context : Context,
  session : OtHandle,
  options : SessionRendererOptions,
) -> Int32 = "ot_session_attach_renderer"

///|
#borrow(session)
extern "C" fn ot_session_close(context : Context, session : OtHandle) -> Int32 = "ot_session_close"

///|
#borrow(session)
extern "C" fn ot_session_cancel(context : Context, session : OtHandle) -> Int32 = "ot_session_cancel"

///|
#borrow(session, out_node)
extern "C" fn ot_scene_create_node(
  context : Context,
  session : OtHandle,
  kind : UInt32,
  num : UInt32,
  out_node : HandleOut,
) -> Int32 = "ot_scene_create_node"

///|
#borrow(node, parent)
extern "C" fn ot_scene_move_node(
  context : Context,
  node : OtHandle,
  parent : OtHandle,
  index : UInt32,
) -> Int32 = "ot_scene_move_node"

///|
#borrow(node, paint)
extern "C" fn ot_scene_set_paint(
  context : Context,
  node : OtHandle,
  paint : ScenePaintOptions,
) -> Int32 = "ot_scene_set_paint"

///|
#borrow(node, bytes)
extern "C" fn ot_scene_set_text(
  context : Context,
  node : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
) -> Int32 = "ot_scene_set_text"

///|
#borrow(session, background, out_frame)
extern "C" fn ot_scene_paint(
  context : Context,
  session : OtHandle,
  background : FixedArray[UInt16],
  use_mouse : UInt32,
  excluded_hit_num : UInt32,
  out_frame : FrameRequestOut,
) -> Int32 = "ot_scene_paint"

///|
#borrow(session, frame_request, out_status)
extern "C" fn ot_scene_frame_commit(
  context : Context,
  session : OtHandle,
  frame_request : SceneFrameRequest,
  force : UInt32,
  out_status : FixedArray[UInt32],
) -> Int32 = "ot_scene_frame_commit"

///|
#borrow(session, bytes, out_ticket)
extern "C" fn ot_session_read_output(
  context : Context,
  session : OtHandle,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_ticket : TicketOut,
) -> Int32 = "ot_session_read_output"

///|
#borrow(session, ticket)
extern "C" fn ot_session_complete_output(
  context : Context,
  session : OtHandle,
  ticket : OutputTicket,
  success : UInt32,
) -> Int32 = "ot_session_complete_output"

///|
#borrow(context, session, options)
extern "C" fn ot_session_setup_terminal(
  context : Context,
  session : OtHandle,
  options : TerminalOptions,
) -> Int32 = "ot_session_setup_terminal"

///|
#borrow(context, session, out_result)
extern "C" fn ot_session_pump(
  context : Context,
  session : OtHandle,
  now_ns : UInt64,
  work_budget : UInt32,
  out_result : PumpResultOut,
) -> Int32 = "ot_session_pump"

///|
#borrow(context, session, out_written)
extern "C" fn ot_session_drain_stdout(
  context : Context,
  session : OtHandle,
  max_bytes : UInt32,
  out_written : FixedArray[UInt32],
) -> Int32 = "ot_session_drain_stdout"

///|
// records 是连续的 ot_input_event 数组缓冲（每条 32 字节，capacity = 长度/32）。
// 不能用 struct 数组：FixedArray[Struct] 是 GC 指针数组（见 types.mbt 陷阱注释）。
#borrow(context, session, bytes, records, payload, out_drain)
extern "C" fn ot_session_input_feed(
  context : Context,
  session : OtHandle,
  bytes : FixedArray[Byte],
  byte_count : UInt32,
  now_ns : UInt64,
  records : FixedArray[Byte],
  capacity : UInt32,
  payload : FixedArray[Byte],
  payload_capacity : UInt32,
  out_drain : InputDrainOut,
) -> Int32 = "ot_session_input_feed"

///|
#borrow(context, session, out_phase)
extern "C" fn ot_session_get_terminal_state(
  context : Context,
  session : OtHandle,
  out_phase : FixedArray[UInt32],
) -> Int32 = "ot_session_get_terminal_state"

///|
#borrow(node, options)
extern "C" fn ot_scene_set_text_options(
  context : Context,
  node : OtHandle,
  options : SceneTextOptions,
) -> Int32 = "ot_scene_set_text_options"

///|
#borrow(updates, out_applied)
extern "C" fn ot_scene_flush(
  context : Context,
  updates : Bytes,
  byte_count : UInt32,
  out_applied : FixedArray[UInt32],
) -> Int32 = "ot_scene_flush"

///|
#borrow(context, node, bytes, chunks, urls)
extern "C" fn ot_scene_set_styled_text(
  context : Context,
  node : OtHandle,
  bytes : FixedArray[Byte],
  byte_count : UInt32,
  chunks : FixedArray[Byte],
  chunk_count : UInt32,
  urls : FixedArray[Byte],
  url_byte_count : UInt32,
) -> Int32 = "ot_scene_set_styled_text"

///|
#borrow(context, node, options)
extern "C" fn ot_scene_set_slider(
  context : Context,
  node : OtHandle,
  options : SliderOptions,
) -> Int32 = "ot_scene_set_slider"

///|
#borrow(context, session, out_num)
extern "C" fn ot_scene_hit_test(
  context : Context,
  session : OtHandle,
  x : Int32,
  y : Int32,
  out_num : FixedArray[UInt32],
) -> Int32 = "ot_scene_hit_test"

///|
// bytes 可为空负载（标题等无负载控制包）；payload 空串即零长度。
#borrow(context, session, options, bytes)
extern "C" fn ot_session_control(
  context : Context,
  session : OtHandle,
  options : ControlOptions,
  bytes : Bytes,
  byte_count : UInt32,
) -> Int32 = "ot_session_control"

///|
// title 零长度表示省略（原生侧约定：NULL 要求零长度，这里恒传缓冲）。
#borrow(context, session, message, title, out_written)
extern "C" fn ot_session_notification(
  context : Context,
  session : OtHandle,
  message : Bytes,
  message_len : UInt32,
  title : Bytes,
  title_len : UInt32,
  out_written : FixedArray[UInt32],
) -> Int32 = "ot_session_notification"

///|
#borrow(context, session, out_link_id)
extern "C" fn ot_session_get_link_id(
  context : Context,
  session : OtHandle,
  x : Int32,
  y : Int32,
  out_link_id : FixedArray[UInt32],
) -> Int32 = "ot_session_get_link_id"

///|
#borrow(context, bytes, out_count)
extern "C" fn ot_context_get_link_url(
  context : Context,
  link_id : UInt32,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_context_get_link_url"

///|
#borrow(context, options, out_buffer)
extern "C" fn ot_buffer_create(
  context : Context,
  options : BufferOptions,
  out_buffer : HandleOut,
) -> Int32 = "ot_buffer_create"

///|
#borrow(buffer)
extern "C" fn ot_buffer_destroy(context : Context, buffer : OtHandle) -> Int32 = "ot_buffer_destroy"

///|
#borrow(buffer)
extern "C" fn ot_buffer_resize(
  context : Context,
  buffer : OtHandle,
  width : UInt32,
  height : UInt32,
) -> Int32 = "ot_buffer_resize"

///|

///|
#borrow(context, node, hooks)
extern "C" fn ot_scene_set_hooks(
  context : Context,
  node : OtHandle,
  hooks : SceneHooks,
) -> Int32 = "ot_scene_set_hooks"

///|
// previous 为 UInt64：0 = 开始新尝试；非 0 路径用同符号的 *_ack 变体。
#borrow(context, session, options, recording, out_request, out_geometry)
extern "C" fn ot_scene_frame_step(
  context : Context,
  session : OtHandle,
  options : SceneFrameOptions,
  recording : Bytes,
  recording_length : UInt32,
  out_request : FrameRequestOut,
  out_geometry : FixedArray[Byte],
) -> Int32 = "ot_scene_frame_step_begin"

///|
// previous 非 NULL：确认上一次返回的请求（含全部身份与尺寸）。
#borrow(context, session, previous, options, recording, out_request, out_geometry)
extern "C" fn ot_scene_frame_step_ack(
  context : Context,
  session : OtHandle,
  previous : SceneFrameRequest,
  options : SceneFrameOptions,
  recording : Bytes,
  recording_length : UInt32,
  out_request : FrameRequestOut,
  out_geometry : FixedArray[Byte],
) -> Int32 = "ot_scene_frame_step_confirm"

///|
#borrow(context, session, record_request, out_slots, out_count)
extern "C" fn ot_scene_frame_get_paint_slots(
  context : Context,
  session : OtHandle,
  record_request : SceneFrameRequest,
  out_slots : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_scene_frame_get_paint_slots"

///|
#borrow(context, node, options, out_changed)
extern "C" fn ot_scene_set_text_selection(
  context : Context,
  node : OtHandle,
  options : TextSelectionOptions,
  out_changed : FixedArray[UInt32],
) -> Int32 = "ot_scene_set_text_selection"

///|
#borrow(context, node, out_packed)
extern "C" fn ot_scene_get_text_selection(
  context : Context,
  node : OtHandle,
  out_packed : FixedArray[UInt64],
) -> Int32 = "ot_scene_get_text_selection"

///|
#borrow(context, node, bytes, out_count)
extern "C" fn ot_scene_get_selected_text(
  context : Context,
  node : OtHandle,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_scene_get_selected_text"

///|
#borrow(context, node, out_layout)
extern "C" fn ot_scene_get_layout(
  context : Context,
  node : OtHandle,
  observation : UInt32,
  out_layout : SceneLayout,
) -> Int32 = "ot_scene_get_layout"

///|
#borrow(context, options, out_buffer)
extern "C" fn ot_edit_buffer_create(
  context : Context,
  options : EditBufferOptions,
  out_buffer : HandleOut,
) -> Int32 = "ot_edit_buffer_create"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_destroy(context : Context, buffer : OtHandle) -> Int32 = "ot_edit_buffer_destroy"

///|
#borrow(buffer, bytes)
extern "C" fn ot_edit_buffer_set_text(
  context : Context,
  buffer : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
  preserve_history : UInt32,
) -> Int32 = "ot_edit_buffer_set_text"

///|
#borrow(buffer, bytes)
extern "C" fn ot_edit_buffer_insert_text(
  context : Context,
  buffer : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
) -> Int32 = "ot_edit_buffer_insert_text"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_delete_range(
  context : Context,
  buffer : OtHandle,
  start_row : UInt32,
  start_col : UInt32,
  end_row : UInt32,
  end_col : UInt32,
) -> Int32 = "ot_edit_buffer_delete_range"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_set_cursor(
  context : Context,
  buffer : OtHandle,
  row : UInt32,
  col : UInt32,
) -> Int32 = "ot_edit_buffer_set_cursor"

///|
#borrow(buffer, bytes, out_count)
extern "C" fn ot_edit_buffer_get_text(
  context : Context,
  buffer : OtHandle,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_edit_buffer_get_text"

///|
#borrow(buffer, out_info)
extern "C" fn ot_edit_buffer_get_info(
  context : Context,
  buffer : OtHandle,
  out_info : EditBufferInfo,
) -> Int32 = "ot_edit_buffer_get_info"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_set_tab_width(
  context : Context,
  buffer : OtHandle,
  width : UInt32,
) -> Int32 = "ot_edit_buffer_set_tab_width"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_command(
  context : Context,
  buffer : OtHandle,
  command : UInt32,
  argument : UInt32,
) -> Int32 = "ot_edit_buffer_command"

///|
#borrow(buffer, highlight)
extern "C" fn ot_edit_buffer_highlight(
  context : Context,
  buffer : OtHandle,
  operation : UInt32,
  argument : UInt32,
  highlight : EditHighlight,
) -> Int32 = "ot_edit_buffer_highlight"

///|
#borrow(context, buffer, out_view)
extern "C" fn ot_editor_view_create(
  context : Context,
  buffer : OtHandle,
  width : UInt32,
  height : UInt32,
  out_view : HandleOut,
) -> Int32 = "ot_editor_view_create"

///|
#borrow(view)
extern "C" fn ot_editor_view_destroy(context : Context, view : OtHandle) -> Int32 = "ot_editor_view_destroy"

///|
#borrow(view, viewport)
extern "C" fn ot_editor_view_set_viewport(
  context : Context,
  view : OtHandle,
  viewport : EditorViewport,
  size_only : UInt32,
  move_cursor : UInt32,
) -> Int32 = "ot_editor_view_set_viewport"

///|
#borrow(view)
extern "C" fn ot_editor_view_command(
  context : Context,
  view : OtHandle,
  command : UInt32,
  argument : UInt32,
) -> Int32 = "ot_editor_view_command"

///|
#borrow(view, bytes, out_steps)
extern "C" fn ot_editor_view_replace_selection(
  context : Context,
  view : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
  out_steps : FixedArray[UInt32],
) -> Int32 = "ot_editor_view_replace_selection"

///|
#borrow(context, node, view)
extern "C" fn ot_scene_set_editor_view(
  context : Context,
  node : OtHandle,
  view : OtHandle,
) -> Int32 = "ot_scene_set_editor_view"

///|
#borrow(context, node, options)
extern "C" fn ot_scene_set_editor_options(
  context : Context,
  node : OtHandle,
  options : SceneEditorOptions,
) -> Int32 = "ot_scene_set_editor_options"

///|
#borrow(view, out_info)
extern "C" fn ot_editor_view_get_info(
  context : Context,
  view : OtHandle,
  follow_cursor : UInt32,
  out_info : EditorViewInfo,
) -> Int32 = "ot_editor_view_get_info"

///|
#borrow(view, bytes, out_count)
extern "C" fn ot_editor_view_get_selected_text(
  context : Context,
  view : OtHandle,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_editor_view_get_selected_text"

///|
#borrow(view, out_position)
extern "C" fn ot_editor_view_get_position(
  context : Context,
  view : OtHandle,
  query : UInt32,
  out_position : EditorPosition,
) -> Int32 = "ot_editor_view_get_position"

///|
#borrow(buffer, out_position)
extern "C" fn ot_edit_buffer_get_position(
  context : Context,
  buffer : OtHandle,
  query : UInt32,
  a : UInt32,
  b : UInt32,
  out_position : EditPosition,
) -> Int32 = "ot_edit_buffer_get_position"

///|
// 空文本清空对应 selection。
#borrow(context, session, bytes, out_written)
extern "C" fn ot_session_clipboard(
  context : Context,
  session : OtHandle,
  target : UInt32,
  bytes : Bytes,
  byte_count : UInt32,
  out_written : FixedArray[UInt32],
) -> Int32 = "ot_session_clipboard"

///|
#borrow(view, selection, out_changed)
extern "C" fn ot_editor_view_select_shim(
  context : Context,
  view : OtHandle,
  selection : EditorSelection,
  out_changed : FixedArray[UInt32],
) -> Int32 = "ot_editor_view_select"

///|
#borrow(buffer, highlight)
extern "C" fn ot_edit_buffer_highlight_add_range_shim(
  context : Context,
  buffer : OtHandle,
  highlight : EditHighlight,
) -> Int32 = "ot_edit_buffer_highlight_add_range"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_highlight_remove_ref_shim(
  context : Context,
  buffer : OtHandle,
  ref_ : UInt32,
) -> Int32 = "ot_edit_buffer_highlight_remove_ref"

///|
#borrow(buffer)
extern "C" fn ot_edit_buffer_highlight_clear_shim(
  context : Context,
  buffer : OtHandle,
) -> Int32 = "ot_edit_buffer_highlight_clear"

///|
// 语法样式表：注册采用打包 shim（editor_style 内联为标量）。
#borrow(context, out_style)
extern "C" fn ot_syntax_style_create(
  context : Context,
  out_style : HandleOut,
) -> Int32 = "ot_syntax_style_create"

///|
#borrow(style)
extern "C" fn ot_syntax_style_destroy(context : Context, style : OtHandle) -> Int32 = "ot_syntax_style_destroy"

///|
#borrow(context, style, bytes, out_id)
extern "C" fn ot_syntax_style_register_packed(
  context : Context,
  style : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
  flags : UInt32,
  attributes : UInt32,
  fg01 : UInt32,
  fg23 : UInt32,
  bg01 : UInt32,
  bg23 : UInt32,
  out_id : FixedArray[UInt32],
) -> Int32 = "ot_syntax_style_register_packed"

///|
#borrow(context, style, bytes, out_id)
extern "C" fn ot_syntax_style_resolve(
  context : Context,
  style : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
  out_id : FixedArray[UInt32],
) -> Int32 = "ot_syntax_style_resolve"

///|
#borrow(context, style, out_count)
extern "C" fn ot_syntax_style_get_count(
  context : Context,
  style : OtHandle,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_syntax_style_get_count"

///|
// 共享文本缓冲（TextBuffer）：与 EditBuffer 同参形态的创建/销毁。
#borrow(context, options, out_buffer)
extern "C" fn ot_text_buffer_create(
  context : Context,
  options : EditBufferOptions,
  out_buffer : HandleOut,
) -> Int32 = "ot_text_buffer_create"

///|
#borrow(buffer)
extern "C" fn ot_text_buffer_destroy(context : Context, buffer : OtHandle) -> Int32 = "ot_text_buffer_destroy"

///|
#borrow(buffer, bytes)
extern "C" fn ot_text_buffer_set_text(
  context : Context,
  buffer : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
) -> Int32 = "ot_text_buffer_set_text"

///|
#borrow(buffer, bytes)
extern "C" fn ot_text_buffer_append(
  context : Context,
  buffer : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
) -> Int32 = "ot_text_buffer_append"

///|
#borrow(buffer)
extern "C" fn ot_text_buffer_clear(
  context : Context,
  buffer : OtHandle,
  reset : UInt32,
) -> Int32 = "ot_text_buffer_clear"

///|
#borrow(context, buffer, bytes, chunks, urls)
extern "C" fn ot_text_buffer_set_styled_text(
  context : Context,
  buffer : OtHandle,
  bytes : FixedArray[Byte],
  byte_count : UInt32,
  chunks : FixedArray[Byte],
  chunk_count : UInt32,
  urls : FixedArray[Byte],
  url_byte_count : UInt32,
) -> Int32 = "ot_text_buffer_set_styled_text"

///|
#borrow(context, buffer, style)
extern "C" fn ot_text_buffer_set_syntax_style(
  context : Context,
  buffer : OtHandle,
  style : OtHandle,
) -> Int32 = "ot_text_buffer_set_syntax_style"

///|
#borrow(buffer, out_info)
extern "C" fn ot_text_buffer_get_info(
  context : Context,
  buffer : OtHandle,
  out_info : TextBufferInfo,
) -> Int32 = "ot_text_buffer_get_info"

///|
#borrow(buffer, bytes, out_count)
extern "C" fn ot_text_buffer_get_text(
  context : Context,
  buffer : OtHandle,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_get_text"

///|
#borrow(buffer, bytes, out_count)
extern "C" fn ot_text_buffer_get_range(
  context : Context,
  buffer : OtHandle,
  start : UInt32,
  end : UInt32,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_get_range"

///|
#borrow(context, buffer, mask, flags, attributes, fg01, fg23, bg01, bg23)
extern "C" fn ot_text_buffer_set_defaults_packed(
  context : Context,
  buffer : OtHandle,
  mask : UInt32,
  flags : UInt32,
  attributes : UInt32,
  fg01 : UInt32,
  fg23 : UInt32,
  bg01 : UInt32,
  bg23 : UInt32,
) -> Int32 = "ot_text_buffer_set_defaults_packed"

///|
#borrow(buffer)
extern "C" fn ot_text_buffer_set_tab_width(
  context : Context,
  buffer : OtHandle,
  width : UInt32,
) -> Int32 = "ot_text_buffer_set_tab_width"

///|
// text_buffer_highlight 的三个常用路径（与 edit_buffer 同套 shim）。
#borrow(buffer, highlight)
extern "C" fn ot_text_buffer_highlight_add_range_shim(
  context : Context,
  buffer : OtHandle,
  highlight : EditHighlight,
) -> Int32 = "ot_text_buffer_highlight_add_range"

///|
#borrow(buffer)
extern "C" fn ot_text_buffer_highlight_remove_ref_shim(
  context : Context,
  buffer : OtHandle,
  ref_ : UInt32,
) -> Int32 = "ot_text_buffer_highlight_remove_ref"

///|
#borrow(buffer)
extern "C" fn ot_text_buffer_highlight_clear_shim(
  context : Context,
  buffer : OtHandle,
) -> Int32 = "ot_text_buffer_highlight_clear"

///|
#borrow(buffer, highlights, out_count)
extern "C" fn ot_text_buffer_get_highlights(
  context : Context,
  buffer : OtHandle,
  line : UInt32,
  highlights : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_get_highlights"

///|
#borrow(context, buffer, out_view)
extern "C" fn ot_text_buffer_view_create(
  context : Context,
  buffer : OtHandle,
  out_view : HandleOut,
) -> Int32 = "ot_text_buffer_view_create"

///|
#borrow(view)
extern "C" fn ot_text_buffer_view_destroy(context : Context, view : OtHandle) -> Int32 = "ot_text_buffer_view_destroy"

///|
#borrow(view, viewport)
extern "C" fn ot_text_buffer_view_set_viewport(
  context : Context,
  view : OtHandle,
  viewport : EditorViewport,
  size_only : UInt32,
) -> Int32 = "ot_text_buffer_view_set_viewport"

///|
#borrow(view)
extern "C" fn ot_text_buffer_view_command(
  context : Context,
  view : OtHandle,
  command : UInt32,
  argument : UInt32,
) -> Int32 = "ot_text_buffer_view_command"

///|
#borrow(view, color)
extern "C" fn ot_text_buffer_view_set_tab_color(
  context : Context,
  view : OtHandle,
  color : Rgba16,
) -> Int32 = "ot_text_buffer_view_set_tab_color"

///|
#borrow(view, selection, out_changed)
extern "C" fn ot_text_buffer_view_select(
  context : Context,
  view : OtHandle,
  selection : EditorSelection,
  out_changed : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_view_select"

///|
#borrow(view, out_info)
extern "C" fn ot_text_buffer_view_get_info(
  context : Context,
  view : OtHandle,
  out_info : EditorViewInfo,
) -> Int32 = "ot_text_buffer_view_get_info"

///|
#borrow(view, bytes, out_count)
extern "C" fn ot_text_buffer_view_get_selected_text(
  context : Context,
  view : OtHandle,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_view_get_selected_text"

///|
// 行列表 + measure 用 shim 合并 out；lines 是连续 ot_scene_text_line 缓冲。
#borrow(view, lines, out_pairs)
extern "C" fn ot_text_buffer_view_get_lines_shim(
  context : Context,
  view : OtHandle,
  logical : UInt32,
  first_line : UInt32,
  lines : FixedArray[Byte],
  capacity : UInt32,
  out_pairs : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_view_get_lines_shim"

///|
#borrow(view, out_pairs)
extern "C" fn ot_text_buffer_view_measure_shim(
  context : Context,
  view : OtHandle,
  width : UInt32,
  height : UInt32,
  out_pairs : FixedArray[UInt32],
) -> Int32 = "ot_text_buffer_view_measure_shim"

///|
// TEXT_VIEW 节点绑定与内置绘制开关。
#borrow(context, node, view)
extern "C" fn ot_scene_set_text_view(
  context : Context,
  node : OtHandle,
  view : OtHandle,
) -> Int32 = "ot_scene_set_text_view"

///|
#borrow(context, node)
extern "C" fn ot_scene_set_text_view_paint(
  context : Context,
  node : OtHandle,
  enabled : UInt32,
) -> Int32 = "ot_scene_set_text_view_paint"

///|
// 编辑器扩展：占位符（纯文本 shim）/滚动边距/制表符颜色/选区信息。
#borrow(context, view, bytes)
extern "C" fn ot_editor_view_set_placeholder_text(
  context : Context,
  view : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
) -> Int32 = "ot_editor_view_set_placeholder_text"

///|
#borrow(context, view)
extern "C" fn ot_editor_view_set_scroll_margin(
  context : Context,
  view : OtHandle,
  margin : Float,
) -> Int32 = "ot_editor_view_set_scroll_margin"

///|
#borrow(context, view, color)
extern "C" fn ot_editor_view_set_tab_color(
  context : Context,
  view : OtHandle,
  color : Rgba16,
) -> Int32 = "ot_editor_view_set_tab_color"

///|
#borrow(context, view, lines, out_pairs)
extern "C" fn ot_editor_view_get_lines_shim(
  context : Context,
  view : OtHandle,
  logical : UInt32,
  lines : FixedArray[Byte],
  capacity : UInt32,
  out_pairs : FixedArray[UInt32],
) -> Int32 = "ot_editor_view_get_lines_shim"

///|
#borrow(context, view, out_pairs)
extern "C" fn ot_editor_view_measure_shim(
  context : Context,
  view : OtHandle,
  width : UInt32,
  height : UInt32,
  out_pairs : FixedArray[UInt32],
) -> Int32 = "ot_editor_view_measure_shim"

///|
#borrow(context, view, out_info)
extern "C" fn ot_editor_view_get_selection(
  context : Context,
  view : OtHandle,
  out_info : EditorViewInfo,
) -> Int32 = "ot_editor_view_get_selection"

///|
// 撤销/重做：把交换出的文本片段回传（零容量只报字节数）。
#borrow(context, buffer, bytes, out_count)
extern "C" fn ot_edit_buffer_history(
  context : Context,
  buffer : OtHandle,
  redo : UInt32,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_edit_buffer_history"

///|
#borrow(context, buffer, bytes, out_width)
extern "C" fn ot_edit_buffer_measure_text(
  context : Context,
  buffer : OtHandle,
  bytes : Bytes,
  byte_count : UInt32,
  out_width : FixedArray[UInt32],
) -> Int32 = "ot_edit_buffer_measure_text"

///|
#borrow(context, bytes, out_width)
extern "C" fn ot_edit_measure_text(
  context : Context,
  bytes : Bytes,
  byte_count : UInt32,
  width_method : UInt32,
  tab_width : UInt32,
  out_width : FixedArray[UInt32],
) -> Int32 = "ot_edit_measure_text"

///|
#borrow(context, buffer, mask, flags, attributes, fg01, fg23, bg01, bg23)
extern "C" fn ot_edit_buffer_set_defaults_packed(
  context : Context,
  buffer : OtHandle,
  mask : UInt32,
  flags : UInt32,
  attributes : UInt32,
  fg01 : UInt32,
  fg23 : UInt32,
  bg01 : UInt32,
  bg23 : UInt32,
) -> Int32 = "ot_edit_buffer_set_defaults_packed"

///|
#borrow(buffer, bytes, out_count)
extern "C" fn ot_edit_buffer_get_range(
  context : Context,
  buffer : OtHandle,
  by_coords : UInt32,
  start_row : UInt32,
  start_col : UInt32,
  end_row : UInt32,
  end_col : UInt32,
  bytes : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_edit_buffer_get_range"

///|
#borrow(buffer, highlights, out_count)
extern "C" fn ot_edit_buffer_get_highlights(
  context : Context,
  buffer : OtHandle,
  line : UInt32,
  highlights : FixedArray[Byte],
  capacity : UInt32,
  out_count : FixedArray[UInt32],
) -> Int32 = "ot_edit_buffer_get_highlights"

///|
// 图像：像素缓冲用 FixedArray[Byte] 直传（原生只读/只写不持有）。
#borrow(context, bytes, out_info)
extern "C" fn ot_image_inspect(
  context : Context,
  bytes : FixedArray[Byte],
  byte_count : UInt64,
  out_info : ImageInfo,
) -> Int32 = "ot_image_inspect"

///|
#borrow(context, bytes, out_image)
extern "C" fn ot_image_decode(
  context : Context,
  bytes : FixedArray[Byte],
  byte_count : UInt64,
  out_image : HandleOut,
) -> Int32 = "ot_image_decode"

///|
#borrow(context, pixels, out_image)
extern "C" fn ot_image_create_pixels(
  context : Context,
  pixels : FixedArray[Byte],
  byte_count : UInt64,
  width : UInt32,
  height : UInt32,
  stride : UInt32,
  format : UInt32,
  alpha : UInt32,
  out_image : HandleOut,
) -> Int32 = "ot_image_create_pixels"

///|
#borrow(context, image, pixels)
extern "C" fn ot_image_update_pixels(
  context : Context,
  image : OtHandle,
  pixels : FixedArray[Byte],
  byte_count : UInt64,
  stride : UInt32,
  format : UInt32,
  alpha : UInt32,
) -> Int32 = "ot_image_update_pixels"

///|
#borrow(image)
extern "C" fn ot_image_destroy(context : Context, image : OtHandle) -> Int32 = "ot_image_destroy"

///|
#borrow(context, image, out_info)
extern "C" fn ot_image_get_info(
  context : Context,
  image : OtHandle,
  out_info : ImageInfo,
) -> Int32 = "ot_image_get_info"

///|
#borrow(context, image, out_image)
extern "C" fn ot_image_resize(
  context : Context,
  image : OtHandle,
  width : UInt32,
  height : UInt32,
  filter : UInt32,
  out_image : HandleOut,
) -> Int32 = "ot_image_resize"

///|
#borrow(context, image, out_image)
extern "C" fn ot_image_extract(
  context : Context,
  image : OtHandle,
  left : UInt32,
  top : UInt32,
  width : UInt32,
  height : UInt32,
  out_image : HandleOut,
) -> Int32 = "ot_image_extract"

///|
#borrow(context, image, background, out_image)
extern "C" fn ot_image_extend(
  context : Context,
  image : OtHandle,
  top : UInt32,
  right : UInt32,
  bottom : UInt32,
  left : UInt32,
  background : FixedArray[Byte],
  out_image : HandleOut,
) -> Int32 = "ot_image_extend"

///|
#borrow(context, image, out_image)
extern "C" fn ot_image_transform(
  context : Context,
  image : OtHandle,
  operation : UInt32,
  out_image : HandleOut,
) -> Int32 = "ot_image_transform"

///|
#borrow(context, base, overlay, out_image)
extern "C" fn ot_image_composite(
  context : Context,
  base : OtHandle,
  overlay : OtHandle,
  left : Int32,
  top : Int32,
  blend : UInt32,
  opacity : Byte,
  out_image : HandleOut,
) -> Int32 = "ot_image_composite"

///|
#borrow(context, image, destination)
extern "C" fn ot_image_copy_pixels(
  context : Context,
  image : OtHandle,
  destination : FixedArray[Byte],
  byte_count : UInt64,
  stride : UInt32,
  format : UInt32,
) -> Int32 = "ot_image_copy_pixels"

///|
#borrow(context, image, destination, out_byte_count)
extern "C" fn ot_image_copy_png(
  context : Context,
  image : OtHandle,
  destination : FixedArray[Byte],
  capacity : UInt64,
  out_byte_count : FixedArray[UInt64],
) -> Int32 = "ot_image_copy_png"

///|
// IMAGE 节点绑定：buffer 参数固定 NULL（非缓冲绘制路径）。
#borrow(context, node, image)
extern "C" fn ot_scene_set_image_shim(
  context : Context,
  node : OtHandle,
  image : OtHandle,
  fit : UInt32,
  protocol : UInt32,
) -> Int32 = "ot_scene_set_image_null_buffer"

///|
#borrow(context, session)
extern "C" fn ot_session_set_image_resolution(
  context : Context,
  session : OtHandle,
  terminal_width : UInt32,
  terminal_height : UInt32,
  pixel_width : UInt32,
  pixel_height : UInt32,
) -> Int32 = "ot_session_set_image_resolution"

///|
#borrow(context, session)
extern "C" fn ot_session_set_kitty_image_transport(
  context : Context,
  session : OtHandle,
  mode : UInt32,
) -> Int32 = "ot_session_set_kitty_image_transport"

///|
#borrow(context, session, out_status)
extern "C" fn ot_session_get_kitty_image_transport(
  context : Context,
  session : OtHandle,
  out_status : KittyTransportStatus,
) -> Int32 = "ot_session_get_kitty_image_transport"

///|
#borrow(context, session, out_retry)
extern "C" fn ot_session_poll_kitty_image_transport(
  context : Context,
  session : OtHandle,
  now_ns : UInt64,
  out_retry : FixedArray[UInt32],
) -> Int32 = "ot_session_poll_kitty_image_transport"

///|
#borrow(context, session)
extern "C" fn ot_session_cancel_kitty_image_transport(
  context : Context,
  session : OtHandle,
  failed : UInt32,
) -> Int32 = "ot_session_cancel_kitty_image_transport"

///|
#borrow(context, session, bytes, out_result)
extern "C" fn ot_session_process_kitty_image_reply(
  context : Context,
  session : OtHandle,
  bytes : FixedArray[Byte],
  byte_count : UInt32,
  out_result : FixedArray[UInt32],
) -> Int32 = "ot_session_process_kitty_image_reply"

///|
#borrow(context, session)
extern "C" fn ot_session_start_kitty_file_probe(
  context : Context,
  session : OtHandle,
) -> Int32 = "ot_session_start_kitty_file_probe"

///|
// 分屏：frame 可空（纯 snapshot 提交），snapshots 是 24 字节/条的连续缓冲。
#borrow(context, session, snapshots, out_status)
extern "C" fn ot_session_render_split_no_frame_shim(
  context : Context,
  session : OtHandle,
  snapshots : FixedArray[Byte],
  count : UInt32,
  pinned_render_offset : UInt32,
  force : UInt32,
  out_status : FixedArray[UInt32],
) -> Int32 = "ot_session_render_split_no_frame"

///|
#borrow(context, session, frame, snapshots, out_status)
extern "C" fn ot_session_render_split_with_frame_shim(
  context : Context,
  session : OtHandle,
  frame : SceneFrameRequest,
  snapshots : FixedArray[Byte],
  count : UInt32,
  pinned_render_offset : UInt32,
  force : UInt32,
  out_status : FixedArray[UInt32],
) -> Int32 = "ot_session_render_split_with_frame"

///|
#borrow(context, session, control, out_offset)
extern "C" fn ot_session_split_control(
  context : Context,
  session : OtHandle,
  control : SplitControl,
  out_offset : FixedArray[UInt32],
) -> Int32 = "ot_session_split_control"

///|
#borrow(context, session, trailing)
extern "C" fn ot_session_set_screen(
  context : Context,
  session : OtHandle,
  alternate : UInt32,
  width : UInt32,
  height : UInt32,
  trailing : FixedArray[Byte],
  byte_count : UInt32,
) -> Int32 = "ot_session_set_screen"

///|
#borrow(context, session)
extern "C" fn ot_session_suspend(context : Context, session : OtHandle) -> Int32 = "ot_session_suspend"

///|
#borrow(context, session)
extern "C" fn ot_session_resume(context : Context, session : OtHandle) -> Int32 = "ot_session_resume"

///|
#borrow(context, session, out_state)
extern "C" fn ot_session_get_renderer_state(
  context : Context,
  session : OtHandle,
  out_state : RendererState,
) -> Int32 = "ot_session_get_renderer_state"

///|
#borrow(context, session, enabled, corner)
extern "C" fn ot_session_set_debug_overlay(
  context : Context,
  session : OtHandle,
  enabled : UInt32,
  corner : UInt32,
) -> Int32 = "ot_session_set_debug_overlay"

///|
#borrow(context, session, out_state)
extern "C" fn ot_session_get_state(
  context : Context,
  session : OtHandle,
  out_state : FixedArray[UInt32],
) -> Int32 = "ot_session_get_state"

///|
#borrow(context, session, overall_ms, fps, callback_ms)
extern "C" fn ot_session_update_stats(
  context : Context,
  session : OtHandle,
  overall_ms : Double,
  fps : UInt32,
  callback_ms : Double,
) -> Int32 = "ot_session_update_stats"

///|
#borrow(context, session, palette, foreground, background)
extern "C" fn ot_session_set_palette_state(
  context : Context,
  session : OtHandle,
  palette : FixedArray[Byte],
  color_count : UInt32,
  foreground : FixedArray[Byte],
  background : FixedArray[Byte],
  epoch : UInt32,
) -> Int32 = "ot_session_set_palette_state"
