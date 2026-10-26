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
