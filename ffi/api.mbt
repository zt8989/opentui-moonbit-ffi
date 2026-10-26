// OpenTUI FFI 高层 API：自动填充版本化记录头、ot_status 到 Result 的转换、
// 颜色打包与 UTF-8 文本编码。

///|
/// 一次原生调用失败。status 为 opentui.h 定义的 ot_status（非 OT_OK）。
pub struct NativeError {
  operation : String
  status : Int32
}

///|
/// 将 ot_status 转为可读名称（完整对照见 opentui.h）。
pub fn status_name(status : Int32) -> String {
  match status {
    0 => "OT_OK"
    -1 => "OT_INVALID_ARGUMENT"
    -2 => "OT_UNSUPPORTED_VERSION"
    -3 => "OT_OUT_OF_MEMORY"
    -4 => "OT_WRONG_THREAD"
    -5 => "OT_INTERNAL_ERROR"
    -6 => "OT_CONTEXT_BUSY"
    -7 => "OT_WRONG_CONTEXT"
    -8 => "OT_WRONG_KIND"
    -9 => "OT_STALE_HANDLE"
    -10 => "OT_WRONG_SESSION"
    -11 => "OT_OUTPUT_BACKPRESSURE"
    -12 => "OT_SESSION_CLOSED"
    -13 => "OT_OUTPUT_BUSY"
    -14 => "OT_STALE_OUTPUT"
    -15 => "OT_OUTPUT_FAILED"
    -16 => "OT_OBJECT_LIMIT"
    -17 => "OT_RENDERER_ATTACHED"
    -18 => "OT_RENDERER_NOT_ATTACHED"
    -19 => "OT_INVALID_PHASE"
    -20 => "OT_CONTROL_PACKET_LIMIT"
    -21 => "OT_LEASE_LIMIT"
    -22 => "OT_LEASE_BYTES_LIMIT"
    -23 => "OT_STALE_LEASE"
    -24 => "OT_UNSUPPORTED_RESOURCE"
    -25 => "OT_STALE_FRAME"
    -26 => "OT_LAYOUT_LIMIT"
    -27 => "OT_FRAME_BUSY"
    -28 => "OT_FRAME_REQUEST_LIMIT"
    _ => "OT_UNKNOWN"
  }
}

///|
/// 手写 to_string 而非 impl Show：避免隐式方法提升的弃用警告。
pub fn NativeError::to_string(self : NativeError) -> String {
  "\{self.operation} failed: \{status_name(self.status)} (\{self.status})"
}

///|
fn check(operation : String, status : Int32) -> Result[Unit, NativeError] {
  if status == OT_OK {
    Ok(())
  } else {
    Err({ operation, status, })
  }
}

///|
/// RGBA 颜色。对应 C 侧 uint16_t[4]：每通道 0..255（低 8 位是 RGBA 字节，
/// 高 8 位留给原生颜色元数据，应用代码必须传 0）。
pub type RgbaColor = (UInt16, UInt16, UInt16, UInt16)

///|
/// 按小端把 uint16_t[4] 的前两个元素打包进一个 UInt32 字段。
pub fn pack_u16x2(lo : UInt16, hi : UInt16) -> UInt32 {
  lo.to_uint() | (hi.to_uint() << 16)
}

///|
fn pack_rgba(c : RgbaColor) -> (UInt32, UInt32) {
  (pack_u16x2(c.0, c.1), pack_u16x2(c.2, c.3))
}

///|
fn rgba_black_opaque() -> RgbaColor {
  (0, 0, 0, 255)
}

///|
fn rgba_white_opaque() -> RgbaColor {
  (255, 255, 255, 255)
}

///|
fn rgba_yellow_opaque() -> RgbaColor {
  (255, 255, 0, 255)
}

///|
/// C: uint16_t background[4] 参数用的固定长度数组。
fn rgba_array(c : RgbaColor) -> FixedArray[UInt16] {
  let arr : FixedArray[UInt16] = FixedArray::make(4, 0)
  arr.set(0, c.0)
  arr.set(1, c.1)
  arr.set(2, c.2)
  arr.set(3, c.3)
  arr
}

///|
pub fn OtHandle::zero() -> OtHandle {
  { context_id: 0, slot: 0, generation: 0, }
}

///|
fn FrameRequestOut::empty() -> FrameRequestOut {
  {
    // out_frame 自身也是版本化记录：调用 paint 前必须填好记录头
    struct_size: 112,
    abi_version: OT_CONTEXT_ABI_VERSION,
    session_context_id: 0,
    session_slot: 0,
    session_generation: 0,
    root_context_id: 0,
    root_slot: 0,
    root_generation: 0,
    node_context_id: 0,
    node_slot: 0,
    node_generation: 0,
    frame_id: 0,
    request_id: 0,
    layout_epoch: 0,
    hook_generation: 0,
    kind: 0,
    num: 0,
    width: 0,
    height: 0,
    reserved0: 0,
    reserved1: 0,
  }
}

///|
fn TicketOut::empty() -> TicketOut {
  {
    session_context_id: 0,
    session_slot: 0,
    session_generation: 0,
    request_id: 0,
    byte_count: 0,
    reserved: 0,
  }
}

///|
fn HandleOut::to_handle(self : HandleOut) -> OtHandle {
  { context_id: self.context_id, slot: self.slot, generation: self.generation, }
}

///|
fn FrameRequestOut::to_request(self : FrameRequestOut) -> SceneFrameRequest {
  {
    struct_size: self.struct_size,
    abi_version: self.abi_version,
    session_context_id: self.session_context_id,
    session_slot: self.session_slot,
    session_generation: self.session_generation,
    root_context_id: self.root_context_id,
    root_slot: self.root_slot,
    root_generation: self.root_generation,
    node_context_id: self.node_context_id,
    node_slot: self.node_slot,
    node_generation: self.node_generation,
    frame_id: self.frame_id,
    request_id: self.request_id,
    layout_epoch: self.layout_epoch,
    hook_generation: self.hook_generation,
    kind: self.kind,
    num: self.num,
    width: self.width,
    height: self.height,
    reserved0: self.reserved0,
    reserved1: self.reserved1,
  }
}

///|
fn TicketOut::to_ticket(self : TicketOut) -> OutputTicket {
  {
    session_context_id: self.session_context_id,
    session_slot: self.session_slot,
    session_generation: self.session_generation,
    request_id: self.request_id,
    byte_count: self.byte_count,
    reserved: self.reserved,
  }
}

///|
/// ot_context_options，struct_size/abi_version 已按 C ABI 填好。
pub fn make_context_options(
  object_capacity : UInt32,
  render_cells_max : UInt32,
) -> ContextOptions {
  {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    flags: 0,
    object_capacity,
    render_cells_max,
    reserved0: 0,
    reserved1: 0,
    reserved2: 0,
  }
}

///|
/// ot_session_options，struct_size/abi_version 已按 C ABI 填好。
pub fn make_session_options(
  chunk_size : UInt32,
  span_capacity : UInt32,
  max_bytes : UInt64,
) -> SessionOptions {
  {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    chunk_size,
    span_capacity,
    max_bytes,
    control_capacity: 0,
    reserved: 0,
  }
}

///|
/// ot_session_renderer_options，struct_size/abi_version 已按 C ABI 填好。
pub fn make_renderer_options(
  width : UInt32,
  height : UInt32,
  remote : UInt32,
) -> SessionRendererOptions {
  {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    width,
    height,
    remote,
    reserved: 0,
  }
}

///|
/// ot_scene_paint_options。paint 记录整体替换节点绘制属性：
/// 不透明节点必须传 opacity = 1.0。colors 未给定的字段按黑色不透明处理。
pub fn make_paint_options(
  background~ : RgbaColor = rgba_black_opaque(),
  border_color~ : RgbaColor = rgba_white_opaque(),
  focused_border_color~ : RgbaColor = rgba_yellow_opaque(),
  border_sides~ : UInt32 = OT_BORDER_ALL_SIDES,
  border_style~ : UInt32 = OT_BORDER_SINGLE,
  should_fill~ : UInt32 = 0,
) -> ScenePaintOptions {
  let bg = pack_rgba(background)
  let bc = pack_rgba(border_color)
  let fbc = pack_rgba(focused_border_color)
  {
    struct_size: 80,
    abi_version: OT_CONTEXT_ABI_VERSION,
    z_index: 0,
    opacity: 1.0,
    translate_x: 0.0,
    translate_y: 0.0,
    border_sides,
    should_fill,
    background01: bg.0,
    background23: bg.1,
    border_color01: bc.0,
    border_color23: bc.1,
    border_style,
    focusable: 0,
    focused_border_color01: fbc.0,
    focused_border_color23: fbc.1,
    reserved: 0,
  }
}

///|
pub fn create_context(
  object_capacity~ : UInt32,
  render_cells_max~ : UInt32,
) -> Result[Context, NativeError] {
  let out = ContextOut::empty()
  let status = ot_context_create(
    make_context_options(object_capacity, render_cells_max),
    out,
  )
  match check("ot_context_create", status) {
    Ok(_) => Ok(out.ptr)
    Err(e) => Err(e)
  }
}

///|
fn ContextOut::empty() -> ContextOut {
  { ptr: 0UL, }
}

///|
pub fn destroy_context(context : Context) -> Result[Unit, NativeError] {
  check("ot_context_destroy", ot_context_destroy(context))
}

///|
pub fn create_session(
  context : Context,
  chunk_size~ : UInt32 = 4096,
  span_capacity~ : UInt32 = 2,
  max_bytes~ : UInt64 = 8192UL,
) -> Result[OtHandle, NativeError] {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let status = ot_session_create(
    context,
    make_session_options(chunk_size, span_capacity, max_bytes),
    out,
  )
  match check("ot_session_create", status) {
    Ok(_) => Ok(out.to_handle())
    Err(e) => Err(e)
  }
}

///|
/// 附加渲染器并划定绘制区域。remote = 1 时不继承本地终端环境。
pub fn attach_renderer(
  context : Context,
  session : OtHandle,
  width~ : UInt32,
  height~ : UInt32,
) -> Result[Unit, NativeError] {
  let options = make_renderer_options(width, height, 1)
  check(
    "ot_session_attach_renderer",
    ot_session_attach_renderer(context, session, options),
  )
}

///|
/// 创建场景节点。num 是应用自选的公开节点号，不能为 0。
/// 首个节点必须是 OT_SCENE_ROOT（顺序错误返回 OT_INVALID_PHASE）。
pub fn create_node(
  context : Context,
  session : OtHandle,
  kind : UInt32,
  num~ : UInt32,
) -> Result[OtHandle, NativeError] {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let status = ot_scene_create_node(context, session, kind, num, out)
  match check("ot_scene_create_node", status) {
    Ok(_) => Ok(out.to_handle())
    Err(e) => Err(e)
  }
}

///|
/// 把 node 挂到 parent 的第 index 个子位置；parent 为 root 时建立场景树。
pub fn move_node(
  context : Context,
  node : OtHandle,
  parent : OtHandle,
  index~ : UInt32,
) -> Result[Unit, NativeError] {
  check("ot_scene_move_node", ot_scene_move_node(context, node, parent, index))
}

///|
pub fn set_paint(
  context : Context,
  node : OtHandle,
  paint : ScenePaintOptions,
) -> Result[Unit, NativeError] {
  check("ot_scene_set_paint", ot_scene_set_paint(context, node, paint))
}

///|
/// 文本按 UTF-8 复制进节点；byte_count 是字节数，不含 NUL。
pub fn set_text(
  context : Context,
  node : OtHandle,
  text : String,
) -> Result[Unit, NativeError] {
  let bytes = @utf8.encode(text)
  check(
    "ot_scene_set_text",
    ot_scene_set_text(
      context,
      node,
      bytes,
      bytes.length().reinterpret_as_uint(),
    ),
  )
}

///|
/// 布局并绘制场景，返回待提交的帧票据（DONE 草稿）。
pub fn paint(
  context : Context,
  session : OtHandle,
  background~ : RgbaColor = rgba_black_opaque(),
) -> Result[SceneFrameRequest, NativeError] {
  let bg = rgba_array(background)
  let out : FrameRequestOut = FrameRequestOut::empty()
  let status = ot_scene_paint(context, session, bg, 0, 0, out)
  match check("ot_scene_paint", status) {
    Ok(_) => Ok(out.to_request())
    Err(e) => Err(e)
  }
}

///|
/// 提交帧草稿并编码输出。返回渲染结果
/// （OT_RENDER_PRESENTED / PENDING / SKIPPED / FAILED）。
pub fn commit_frame(
  context : Context,
  session : OtHandle,
  frame : SceneFrameRequest,
) -> Result[UInt32, NativeError] {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_scene_frame_commit(context, session, frame, 0, out)
  match check("ot_scene_frame_commit", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}

///|
/// 复制一批排队输出到 buf，返回输出票据；ticket.byte_count == 0 表示队列已空。
/// 同一会话同时最多一张未完成票据。
pub fn read_output(
  context : Context,
  session : OtHandle,
  buf : FixedArray[Byte],
) -> Result[OutputTicket, NativeError] {
  let out : TicketOut = TicketOut::empty()
  let status = ot_session_read_output(
    context,
    session,
    buf,
    buf.length().reinterpret_as_uint(),
    out,
  )
  match check("ot_session_read_output", status) {
    Ok(_) => Ok(out.to_ticket())
    Err(e) => Err(e)
  }
}

///|
/// 字节到达目的地后确认交付；success = false 表示传输失败。
pub fn complete_output(
  context : Context,
  session : OtHandle,
  ticket : OutputTicket,
  success~ : Bool,
) -> Result[Unit, NativeError] {
  check(
    "ot_session_complete_output",
    ot_session_complete_output(
      context,
      session,
      ticket,
      if success {
        1
      } else {
        0
      },
    ),
  )
}

///|
pub fn close_session(
  context : Context,
  session : OtHandle,
) -> Result[Unit, NativeError] {
  check("ot_session_close", ot_session_close(context, session))
}

///|
/// 传输丢失等异常路径：丢弃待发输出，不做终端恢复。
pub fn cancel_session(
  context : Context,
  session : OtHandle,
) -> Result[Unit, NativeError] {
  check("ot_session_cancel", ot_session_cancel(context, session))
}
