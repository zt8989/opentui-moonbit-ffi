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
