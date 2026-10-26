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
  chunk_size~ : UInt32 = 4096,
  span_capacity~ : UInt32 = 2,
  max_bytes~ : UInt64 = 8192UL,
  control_capacity~ : UInt32 = 0,
) -> SessionOptions {
  {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    chunk_size,
    span_capacity,
    max_bytes,
    control_capacity,
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
  control_capacity~ : UInt32 = 0,
) -> Result[OtHandle, NativeError] {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let status = ot_session_create(
    context,
    make_session_options(
      chunk_size~,
      span_capacity~,
      max_bytes~,
      control_capacity~,
    ),
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
/// use_mouse=true 时发布本帧命中列表（供 hit_test 查询）。
pub fn paint(
  context : Context,
  session : OtHandle,
  background~ : RgbaColor = rgba_black_opaque(),
  use_mouse~ : Bool = false,
) -> Result[SceneFrameRequest, NativeError] {
  let bg = rgba_array(background)
  let out : FrameRequestOut = FrameRequestOut::empty()
  let status = ot_scene_paint(
    context,
    session,
    bg,
    if use_mouse {
      1
    } else {
      0
    },
    0,
    out,
  )
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

///|
/// 终端 setup 请求：进入备用屏（可选清除）。产生的控制输出由 pump/drain 交付。
pub fn setup_terminal(
  context : Context,
  session : OtHandle,
  alternate_screen~ : Bool = true,
  clear_on_close~ : Bool = false,
) -> Result[Unit, NativeError] {
  let mut flags : UInt32 = 0
  if alternate_screen {
    flags = flags.lor(OT_TERMINAL_ALTERNATE_SCREEN)
  }
  if clear_on_close {
    flags = flags.lor(OT_TERMINAL_CLEAR_ON_CLOSE)
  }
  let options : TerminalOptions = {
    struct_size: 16,
    abi_version: OT_CONTEXT_ABI_VERSION,
    flags,
    kitty_keyboard_flags: 0,
  }
  check(
    "ot_session_setup_terminal",
    ot_session_setup_terminal(context, session, options),
  )
}

///|
/// 终端 phase：UNINITIALIZED / SETTING_UP / ACTIVE。
pub fn terminal_state(
  context : Context,
  session : OtHandle,
) -> Result[UInt32, NativeError] {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_session_get_terminal_state(context, session, out)
  match check("ot_session_get_terminal_state", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}

///|
/// pump 结果：status（OT_PUMP_*）与可选的 deadline。
pub struct Pump {
  status : UInt32
  deadline_ns : UInt64
}

///|
pub fn Pump::status(self : Pump) -> UInt32 {
  self.status
}

///|
pub fn Pump::deadline_ns(self : Pump) -> UInt64 {
  self.deadline_ns
}

///|
/// 推进会话工作（终端 setup/恢复、光标等待等）。
/// now_ns 是单调时钟样本；work_budget 是本次处理的工作项数。
pub fn pump(
  context : Context,
  session : OtHandle,
  now_ns : UInt64,
  work_budget~ : UInt32 = 8,
) -> Result[Pump, NativeError] {
  // 版本化记录：out 自身也要填记录头
  let out : PumpResultOut = {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    status: 0,
    reserved: 0,
    deadline_ns: 0,
  }
  let status = ot_session_pump(context, session, now_ns, work_budget, out)
  match check("ot_session_pump", status) {
    Ok(_) => Ok({ status: out.status, deadline_ns: out.deadline_ns, })
    Err(e) => Err(e)
  }
}

///|
/// 把队列输出直接写进程 stdout（max_bytes 至少 4），返回写入字节数。
pub fn drain_stdout(
  context : Context,
  session : OtHandle,
  max_bytes~ : UInt32 = 4096,
) -> Result[UInt32, NativeError] {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_session_drain_stdout(context, session, max_bytes, out)
  match check("ot_session_drain_stdout", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}

///|
/// 一次 input_feed 的产出：解析出的事件与 payload（raw/text 字节区间指向它）。
pub struct InputEvents {
  events : Array[InputEvent]
  consumed : UInt32
  count : UInt32
  deadline_ns : UInt64
}

///|
pub fn InputEvents::events(self : InputEvents) -> Array[InputEvent] {
  self.events
}

///|
pub fn InputEvents::consumed(self : InputEvents) -> UInt32 {
  self.consumed
}

///|
pub fn InputEvents::count(self : InputEvents) -> UInt32 {
  self.count
}

///|
pub fn InputEvents::deadline_ns(self : InputEvents) -> UInt64 {
  self.deadline_ns
}

///|
pub fn InputEvent::kind(self : InputEvent) -> UInt32 {
  self.kind
}

///|
pub fn InputEvent::action(self : InputEvent) -> UInt32 {
  self.action
}

///|
pub fn InputEvent::modifiers(self : InputEvent) -> UInt32 {
  self.modifiers
}

///|
pub fn InputEvent::code(self : InputEvent) -> UInt32 {
  self.code
}

///|
pub fn InputEvent::text(self : InputEvent) -> String {
  self.text
}

///|
/// 喂入终端输入字节，取回解析好的事件。
/// records_capacity 按需给（每次调用最多解析这么多事件）。
pub fn input_feed(
  context : Context,
  session : OtHandle,
  bytes : FixedArray[Byte],
  byte_count : UInt32,
  now_ns : UInt64,
  records_capacity~ : UInt32 = 16,
  // 库要求 payload_capacity >= OT_INPUT_PAYLOAD_BYTES_MIN (4384)
  payload_capacity~ : UInt32 = 8192,
) -> Result[InputEvents, NativeError] {
  // 每条 ot_input_event 32 字节；缓冲 = capacity * 32
  let records : FixedArray[Byte] = FixedArray::make(
    records_capacity.reinterpret_as_int() * 32,
    0,
  )
  let payload : FixedArray[Byte] = FixedArray::make(
    payload_capacity.reinterpret_as_int(),
    0,
  )
  let drain : InputDrainOut = {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    consumed: 0,
    count: 0,
    payload_len: 0,
    discarded: 0,
    deadline_ns: 0,
  }
  let status = ot_session_input_feed(
    context, session, bytes, byte_count, now_ns, records, records_capacity, payload,
    payload_capacity, drain,
  )
  match check("ot_session_input_feed", status) {
    Ok(_) => {
      let events : Array[InputEvent] = []
      for i in 0..<drain.count.reinterpret_as_int() {
        let base = i * 32
        // 小端展开 ot_input_event（布局见 opentui.h）
        let u8_at = fn(off : Int32) -> UInt32 { records[base + off].to_uint() }
        let u32_at = fn(off : Int32) -> UInt32 {
          u8_at(off) |
          (u8_at(off + 1) << 8) |
          (u8_at(off + 2) << 16) |
          (u8_at(off + 3) << 24)
        }
        let text_len = u32_at(28).reinterpret_as_int()
        let text = if text_len > 0 {
          let text_off = u32_at(24).reinterpret_as_int()
          let buf : FixedArray[Byte] = FixedArray::make(text_len, 0)
          for j in 0..<text_len {
            buf[j] = payload[text_off + j]
          }
          @utf8.decode_lossy(Bytes::from_array(buf[:text_len]).exact_view())
        } else {
          ""
        }
        events.push({
          kind: u8_at(0),
          action: u8_at(1),
          modifiers: u8_at(2),
          flags: u8_at(3),
          code: u32_at(4),
          base_code: u32_at(8),
          x: u32_at(12),
          y: u32_at(14),
          text,
        })
      }
      Ok({
        events,
        consumed: drain.consumed,
        count: drain.count,
        deadline_ns: drain.deadline_ns,
      })
    }
    Err(e) => Err(e)
  }
}

///|
/// ot_scene_text_options：前景/背景/属性/对齐。
pub fn make_text_options(
  foreground~ : RgbaColor = rgba_white_opaque(),
  background~ : RgbaColor = (0, 0, 0, 0),
  attributes~ : UInt32 = 0,
  align~ : UInt32 = 0,
) -> SceneTextOptions {
  let fg = pack_rgba(foreground)
  let bg = pack_rgba(background)
  {
    // 尾部按 8 字节对齐补齐：sizeof(ot_scene_text_options) == 80
    struct_size: 80,
    abi_version: OT_CONTEXT_ABI_VERSION,
    foreground01: fg.0,
    foreground23: fg.1,
    background01: bg.0,
    background23: bg.1,
    attributes,
    wrap_mode: 0,
    truncate: 0,
    first_line_offset: 0,
    scroll_x: 0.0,
    scroll_y: 0.0,
    tab_indicator: 0,
    tab_color_set: 0,
    tab_color01: 0,
    tab_color23: 0,
    text_align: align,
  }
}

///|
pub fn set_text_options(
  context : Context,
  node : OtHandle,
  options : SceneTextOptions,
) -> Result[Unit, NativeError] {
  check(
    "ot_scene_set_text_options",
    ot_scene_set_text_options(context, node, options),
  )
}

///|
pub fn InputEvent::x(self : InputEvent) -> UInt32 {
  self.x
}

///|
pub fn InputEvent::y(self : InputEvent) -> UInt32 {
  self.y
}

///|
/// 直接提交文本滚动偏移（text options 是整体替换记录）。
pub fn set_text_scroll_direct(
  context : Context,
  node : OtHandle,
  x : Double,
  y : Double,
) -> Result[Unit, NativeError] {
  let options : SceneTextOptions = {
    struct_size: 80,
    abi_version: OT_CONTEXT_ABI_VERSION,
    foreground01: 0,
    foreground23: 0,
    background01: 0,
    background23: 0,
    attributes: 0,
    wrap_mode: 0,
    truncate: 0,
    first_line_offset: 0,
    scroll_x: x,
    scroll_y: y,
    tab_indicator: 0,
    tab_color_set: 0,
    tab_color01: 0,
    tab_color23: 0,
    text_align: 0,
  }
  set_text_options(context, node, options)
}

///|
/// 发送控制包（标题 / 鼠标模式 / 程序状态等，kind 取 OT_CONTROL_*）。
/// payload 为 UTF-8 负载（TITLE 用）；产生的输出由 pump/drain 交付。
pub fn send_control(
  context : Context,
  session : OtHandle,
  kind~ : UInt32,
  argument~ : UInt32 = 0,
  payload~ : String = "",
) -> Result[Unit, NativeError] {
  let bytes = @utf8.encode(payload)
  let options : ControlOptions = {
    struct_size: 20,
    abi_version: OT_CONTEXT_ABI_VERSION,
    kind,
    argument,
    reserved: 0,
  }
  check(
    "ot_session_control",
    ot_session_control(
      context,
      session,
      options,
      bytes,
      bytes.length().reinterpret_as_uint(),
    ),
  )
}

///|
/// 一次 OSC 7501 程序状态报告（对应 TS 的 ProgramStatus）。
/// state 取 OT_PROGRAM_STATE_*；blocked_kind 仅 BLOCKED 时有效（取 OT_PROGRAM_KIND_*，
/// 0 表示不带 kind）；progress 仅在 progress=true 且 0..100 时随报告发送；
/// id 空串表示根记录；app/title/message 可选。
pub struct ProgramStatusReport {
  state : UInt32
  blocked_kind : UInt32
  progress : Bool
  progress_value : UInt32
  id : String
  app : String
  title : String
  message : String
}

///|
pub fn ProgramStatusReport::make(
  state~ : UInt32,
  blocked_kind~ : UInt32 = 0,
  progress~ : Bool = false,
  progress_value~ : UInt32 = 0,
  id~ : String = "",
  app~ : String = "",
  title~ : String = "",
  message~ : String = "",
) -> ProgramStatusReport raise {
  if progress && progress_value > 100 {
    raise Failure("progress must be 0..100")
  }
  { state, blocked_kind, progress, progress_value, id, app, title, message, }
}

///|
/// 发送程序状态报告（对应 renderer.setProgramStatus，OSC 7501）。
/// payload = ot_session_program_status（8 个 uint32，无版本化头）
/// + id/app/title/message 的 UTF-8 字节依次相连。
pub fn report_program_status(
  context : Context,
  session : OtHandle,
  report : ProgramStatusReport,
) -> Result[Unit, NativeError] {
  let id = @utf8.encode(report.id)
  let app = @utf8.encode(report.app)
  let title = @utf8.encode(report.title)
  let message = @utf8.encode(report.message)
  let fields : UInt32 = if report.progress {
    OT_PROGRAM_STATUS_PROGRESS
  } else {
    0
  }
  let total = 32 +
    id.length() +
    app.length() +
    title.length() +
    message.length()
  let buf : FixedArray[Byte] = FixedArray::make(
    if total > 0 {
      total
    } else {
      1
    },
    0,
  )
  let put32 = fn(off : Int32, v : UInt32) -> Unit {
    for i in 0..<4 {
      buf[off + i] = ((v >> (i * 8)) & 0xff).reinterpret_as_int().to_byte()
    }
  }
  // 字段偏移：0=state 4=kind 8=fields 12=progress 16=id_len 20=app_len 24=title_len 28=message_len
  put32(0, report.state)
  put32(
    4,
    if report.state == OT_PROGRAM_STATE_BLOCKED {
      report.blocked_kind
    } else {
      0
    },
  )
  put32(8, fields)
  put32(
    12,
    if fields == OT_PROGRAM_STATUS_PROGRESS {
      report.progress_value
    } else {
      0
    },
  )
  put32(16, id.length().reinterpret_as_uint())
  put32(20, app.length().reinterpret_as_uint())
  put32(24, title.length().reinterpret_as_uint())
  put32(28, message.length().reinterpret_as_uint())
  let mut offset = 32
  for bytes in [id, app, title, message] {
    for i in 0..<bytes.length() {
      buf[offset + i] = bytes[i]
    }
    offset += bytes.length()
  }
  let options : ControlOptions = {
    struct_size: 20,
    abi_version: OT_CONTEXT_ABI_VERSION,
    kind: OT_CONTROL_PROGRAM_STATUS,
    argument: 0,
    reserved: 0,
  }
  // ot_session_control 接收不可变 Bytes：把编码好的负载转过去
  let payload = Bytes::from_array(buf[:total])
  check(
    "ot_session_control",
    ot_session_control(
      context,
      session,
      options,
      payload,
      payload.length().reinterpret_as_uint(),
    ),
  )
}

///|
/// 发送终端通知（对应 renderer.triggerNotification）。title 空串表示省略。
/// 返回写入的输出字节数（0 表示终端不支持或输出被拒）。
pub fn trigger_notification(
  context : Context,
  session : OtHandle,
  message~ : String,
  title~ : String = "",
) -> Result[UInt32, NativeError] {
  let msg = @utf8.encode(message)
  let ttl = @utf8.encode(title)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_session_notification(
    context,
    session,
    msg,
    msg.length().reinterpret_as_uint(),
    ttl,
    ttl.length().reinterpret_as_uint(),
    out,
  )
  match check("ot_session_notification", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}

///|
/// 命中 (x, y) 处的链接 ID（无链接返回 0）。需要先渲染过带链接的帧。
pub fn link_id_at(
  context : Context,
  session : OtHandle,
  x : UInt32,
  y : UInt32,
) -> Result[UInt32, NativeError] {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_session_get_link_id(
    context,
    session,
    x.reinterpret_as_int(),
    y.reinterpret_as_int(),
    out,
  )
  match check("ot_session_get_link_id", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}

///|
/// 读取链接 ID 对应的 URL（链接 ID 由 link_id_at 返回，Context 内局部有效）。
pub fn link_url(
  context : Context,
  link_id : UInt32,
) -> Result[String, NativeError] {
  let buf : FixedArray[Byte] = FixedArray::make(512, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_context_get_link_url(context, link_id, buf, 512, out)
  match check("ot_context_get_link_url", status) {
    Ok(_) => {
      let n = out[0].reinterpret_as_int()
      Ok(@utf8.decode_lossy(Bytes::from_array(buf[:n]).exact_view()))
    }
    Err(e) => Err(e)
  }
}

///|
/// 创建离屏 buffer（owned，独立于 Session）。
pub fn create_buffer(
  context : Context,
  width~ : UInt32,
  height~ : UInt32,
  respect_alpha~ : Bool = false,
) -> Result[OtHandle, NativeError] {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let options : BufferOptions = {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    width,
    height,
    width_method: OT_WIDTH_METHOD_WCWIDTH,
    flags: if respect_alpha {
      OT_BUFFER_RESPECT_ALPHA
    } else {
      0
    },
  }
  let status = ot_buffer_create(context, options, out)
  match check("ot_buffer_create", status) {
    Ok(_) => Ok(out.to_handle())
    Err(e) => Err(e)
  }
}

///|
pub fn destroy_buffer(
  context : Context,
  buffer : OtHandle,
) -> Result[Unit, NativeError] {
  check("ot_buffer_destroy", ot_buffer_destroy(context, buffer))
}

// ot_buffer_draw 的记录类型多变体受同一 C 符号限制，且 Bytes 传参经
// 验证与原生期待不符；每种操作经 ffi_stub.c 的 shim，MoonBit struct
// 直接传参（布局与 C 一致），frame=NULL（owned buffer）、source=NULL。

///|
#borrow(context, target, record)
extern "C" fn ot_buffer_draw_clear_op(
  context : Context,
  target : OtHandle,
  record : BufferDrawClear,
) -> Int32 = "ot_buffer_draw_clear_shim"

///|
#borrow(context, target, record)
extern "C" fn ot_buffer_draw_fill_op(
  context : Context,
  target : OtHandle,
  record : BufferDrawFill,
) -> Int32 = "ot_buffer_draw_fill_shim"

///|
#borrow(context, target, record, text)
extern "C" fn ot_buffer_draw_text_op(
  context : Context,
  target : OtHandle,
  record : BufferDrawTextRecord,
  text : Bytes,
  text_len : UInt32,
) -> Int32 = "ot_buffer_draw_text_shim"

///|
#borrow(context, target, record)
extern "C" fn ot_buffer_draw_cell_op(
  context : Context,
  target : OtHandle,
  record : BufferDrawCell,
) -> Int32 = "ot_buffer_draw_cell_shim"

///|
///|
/// 清屏（CLEAR：填空格、白前景、给定背景）。
pub fn buffer_clear(
  context : Context,
  buffer : OtHandle,
  background~ : RgbaColor,
) -> Result[Unit, NativeError] {
  let bg = pack_rgba(background)
  let record : BufferDrawClear = {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    operation: OT_BUFFER_DRAW_CLEAR,
    flags: 0,
    background01: bg.0,
    background23: bg.1,
  }
  check("ot_buffer_draw(CLEAR)", ot_buffer_draw_clear_op(context, buffer, record))
}

///|
/// 填充矩形（FILL，裁剪到目标内）。
pub fn buffer_fill(
  context : Context,
  buffer : OtHandle,
  x~ : Int32,
  y~ : Int32,
  width~ : UInt32,
  height~ : UInt32,
  background~ : RgbaColor,
) -> Result[Unit, NativeError] {
  let bg = pack_rgba(background)
  let record : BufferDrawFill = {
    struct_size: 40,
    abi_version: OT_CONTEXT_ABI_VERSION,
    operation: OT_BUFFER_DRAW_FILL,
    flags: 0,
    x,
    y,
    width,
    height,
    background01: bg.0,
    background23: bg.1,
  }
  check("ot_buffer_draw(FILL)", ot_buffer_draw_fill_op(context, buffer, record))
}

///|
/// 绘制文本（TEXT；background 为 None 时不用 HAS_BACKGROUND，各字形保留目标背景）。
pub fn buffer_draw_text(
  context : Context,
  buffer : OtHandle,
  text~ : String,
  x~ : Int32,
  y~ : Int32,
  foreground~ : RgbaColor,
  background~ : RgbaColor? = None,
  attributes~ : UInt32 = 0,
) -> Result[Unit, NativeError] {
  let fg = pack_rgba(foreground)
  let (flags, bg) = match background {
    Some(c) => {
      let packed = pack_rgba(c)
      (OT_BUFFER_DRAW_HAS_BACKGROUND, packed)
    }
    None => (0, (0, 0))
  }
  let record : BufferDrawTextRecord = {
    struct_size: 44,
    abi_version: OT_CONTEXT_ABI_VERSION,
    operation: OT_BUFFER_DRAW_TEXT,
    flags,
    x,
    y,
    attributes,
    foreground01: fg.0,
    foreground23: fg.1,
    background01: bg.0,
    background23: bg.1,
  }
  let bytes = @utf8.encode(text)
  check(
    "ot_buffer_draw(TEXT)",
    ot_buffer_draw_text_op(
      context,
      buffer,
      record,
      bytes,
      bytes.length().reinterpret_as_uint(),
    ),
  )
}

///|
/// 写单个单元格（CELL；控制字符写空格）。
pub fn buffer_draw_cell(
  context : Context,
  buffer : OtHandle,
  x~ : Int32,
  y~ : Int32,
  character~ : UInt32,
  foreground~ : RgbaColor,
  background~ : RgbaColor,
  attributes~ : UInt32 = 0,
) -> Result[Unit, NativeError] {
  let fg = pack_rgba(foreground)
  let bg = pack_rgba(background)
  let record : BufferDrawCell = {
    struct_size: 48,
    abi_version: OT_CONTEXT_ABI_VERSION,
    operation: OT_BUFFER_DRAW_CELL,
    flags: 0,
    x,
    y,
    character,
    attributes,
    foreground01: fg.0,
    foreground23: fg.1,
    background01: bg.0,
    background23: bg.1,
  }
  check("ot_buffer_draw(CELL)", ot_buffer_draw_cell_op(context, buffer, record))
}

///|
pub fn set_hooks(
  context : Context,
  node : OtHandle,
  flags~ : UInt32,
  generation~ : UInt64,
  initial_width~ : Double = 0.0,
  initial_height~ : Double = 0.0,
) -> Result[Unit, NativeError] {
  let hooks : SceneHooks = {
    struct_size: 40,
    abi_version: OT_CONTEXT_ABI_VERSION,
    flags,
    reserved: 0,
    generation,
    initial_width,
    initial_height,
  }
  check("ot_scene_set_hooks", ot_scene_set_hooks(context, node, hooks))
}

///|
/// ot_scene_frame_options，struct_size/abi_version 已填好。
fn make_frame_options(
  background~ : RgbaColor,
  use_mouse~ : Bool,
  excluded_hit_num~ : UInt32 = 0,
) -> SceneFrameOptions {
  let bg = pack_rgba(background)
  {
    // sizeof(ot_scene_frame_options) == 36：成员对齐 4，无尾部补齐
    struct_size: 36,
    abi_version: OT_CONTEXT_ABI_VERSION,
    background01: bg.0,
    background23: bg.1,
    use_mouse: if use_mouse {
      1
    } else {
      0
    },
    excluded_hit_num,
    max_layout_rounds: 64,
    max_host_requests: 64,
    preserve_unwritten: 0,
  }
}

///|
/// geometry out 缓冲：112 字节，前 8 字节是版本化记录头（struct_size/abi）。
/// 内容（两个 ot_scene_layout）本实现不读取。
fn frame_geometry_out() -> FixedArray[Byte] {
  let buf : FixedArray[Byte] = FixedArray::make(112, 0)
  let put32 = fn(off : Int32, v : UInt32) -> Unit {
    for i in 0..<4 {
      buf[off + i] = ((v >> (i * 8)) & 0xff).reinterpret_as_int().to_byte()
    }
  }
  // 外层 geometry 头 + 两个内嵌 ot_scene_layout 的版本化记录头
  put32(0, 112)
  put32(4, OT_CONTEXT_ABI_VERSION)
  put32(16, 48)
  put32(20, OT_CONTEXT_ABI_VERSION)
  put32(64, 48)
  put32(68, OT_CONTEXT_ABI_VERSION)
  buf
}

///|
/// 开始一次帧尝试（previous = NULL）。返回的请求 kind：
/// OT_SCENE_FRAME_RECORD 需要宿主录制后用 frame_step_ack 确认；
/// OT_SCENE_FRAME_DONE（0）表示尝试完成，可提交。
pub fn frame_step(
  context : Context,
  session : OtHandle,
  background~ : RgbaColor,
  use_mouse~ : Bool,
) -> Result[FrameRequestOut, NativeError] {
  let out : FrameRequestOut = FrameRequestOut::empty()
  let geo = frame_geometry_out()
  let status = ot_scene_frame_step(
    context,
    session,
    make_frame_options(background~, use_mouse~),
    b"",
    0,
    out,
    geo,
  )
  match check("ot_scene_frame_step", status) {
    Ok(_) => Ok(out)
    Err(e) => Err(e)
  }
}

///|
/// 确认上一次的请求并继续帧尝试。recording 为空时继续等下一个 RECORD/DONE。
pub fn frame_step_ack(
  context : Context,
  session : OtHandle,
  previous : SceneFrameRequest,
  background~ : RgbaColor,
  use_mouse~ : Bool,
  recording~ : Bytes,
) -> Result[FrameRequestOut, NativeError] {
  let out : FrameRequestOut = FrameRequestOut::empty()
  let geo = frame_geometry_out()
  let status = ot_scene_frame_step_ack(
    context,
    session,
    previous,
    make_frame_options(background~, use_mouse~),
    recording,
    recording.length().reinterpret_as_uint(),
    out,
    geo,
  )
  match check("ot_scene_frame_step_ack", status) {
    Ok(_) => Ok(out)
    Err(e) => Err(e)
  }
}

///|
/// 一次帧尝试的录制上限：slots 数少（FrameBuffer 节点数），64 足够。
const PAINT_SLOT_BYTES : Int32 = 160

///|
/// 读取 RECORD 请求的全部 slots。返回按绘制顺序的字节记录数组，
/// 每条 160 字节（ot_scene_paint_slot，152 字节补齐到 8 的倍数）。
pub fn frame_paint_slots(
  context : Context,
  session : OtHandle,
  record_request : SceneFrameRequest,
) -> Result[Array[FixedArray[Byte]], NativeError] {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  // 先取 slot 总数
  let status = ot_scene_frame_get_paint_slots(
    context,
    session,
    record_request,
    FixedArray::make(8, 0),
    0,
    out,
  )
  match check("ot_scene_frame_get_paint_slots", status) {
    Err(e) => Err(e)
    Ok(_) => {
      let total = out[0].reinterpret_as_int()
      let slots : Array[FixedArray[Byte]] = []
      if total > 0 {
        let cap = if total > 64 { 64 } else { total }
        let buf : FixedArray[Byte] = FixedArray::make(cap * PAINT_SLOT_BYTES, 0)
        let status2 = ot_scene_frame_get_paint_slots(
          context,
          session,
          record_request,
          buf,
          cap.reinterpret_as_uint(),
          out,
        )
        match check("ot_scene_frame_get_paint_slots", status2) {
          Err(e) => return Err(e)
          Ok(_) =>
            for i in 0..<out[0].reinterpret_as_int() {
              let one : FixedArray[Byte] = FixedArray::make(PAINT_SLOT_BYTES, 0)
              for j in 0..<PAINT_SLOT_BYTES {
                one[j] = buf[i * PAINT_SLOT_BYTES + j]
              }
              slots.push(one)
            }
        }
      }
      Ok(slots)
    }
  }
}

///|
/// 调整离屏 buffer 尺寸。
pub fn buffer_resize(
  context : Context,
  buffer : OtHandle,
  width~ : UInt32,
  height~ : UInt32,
) -> Result[Unit, NativeError] {
  check("ot_buffer_resize", ot_buffer_resize(context, buffer, width, height))
}

///|
/// 应用文本选区（对应 TS 的 sceneSetTextSelection / ot_scene_set_text_selection）。
/// anchor/focus 是相对节点原点的 cell 坐标；operation 取 OT_SCENE_TEXT_SELECTION_*；
/// behavior 取 OT_SCENE_TEXT_SELECTION_CELL/WORD/LINE；bg/fg 为 None 时不设置对应颜色位。
/// 返回选区是否发生变化。
pub fn set_text_selection(
  context : Context,
  node : OtHandle,
  operation~ : UInt32,
  anchor_x~ : Int32,
  anchor_y~ : Int32,
  focus_x~ : Int32,
  focus_y~ : Int32,
  behavior~ : UInt32 = OT_SCENE_TEXT_SELECTION_CELL,
  bg~ : RgbaColor? = None,
  fg~ : RgbaColor? = None,
) -> Result[Bool, NativeError] {
  let (flags, bgp, fgp) = match (bg, fg) {
    (Some(b), Some(f)) => {
      let bp = pack_rgba(b)
      let fp = pack_rgba(f)
      (OT_SCENE_TEXT_SELECTION_BACKGROUND.lor(OT_SCENE_TEXT_SELECTION_FOREGROUND), bp, fp)
    }
    (Some(b), None) => {
      let bp = pack_rgba(b)
      (OT_SCENE_TEXT_SELECTION_BACKGROUND, bp, (0, 0))
    }
    (None, Some(f)) => {
      let fp = pack_rgba(f)
      (OT_SCENE_TEXT_SELECTION_FOREGROUND, (0, 0), fp)
    }
    (None, None) => (0, (0, 0), (0, 0))
  }
  let options : TextSelectionOptions = {
    struct_size: 56,
    abi_version: OT_CONTEXT_ABI_VERSION,
    operation,
    behavior,
    anchor_x,
    anchor_y,
    focus_x,
    focus_y,
    flags,
    reserved: 0,
    background01: bgp.0,
    background23: bgp.1,
    foreground01: fgp.0,
    foreground23: fgp.1,
  }
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_scene_set_text_selection(context, node, options, out)
  match check("ot_scene_set_text_selection", status) {
    Ok(_) => Ok(out[0] != 0)
    Err(e) => Err(e)
  }
}

///|
/// 读取文本选区（对应 ot_scene_get_text_selection）。
/// 返回 (start, end) 字符区间；无选区返回 None。
pub fn get_text_selection(
  context : Context,
  node : OtHandle,
) -> Result[(Int, Int)?, NativeError] {
  let out : FixedArray[UInt64] = FixedArray::make(1, 0)
  let status = ot_scene_get_text_selection(context, node, out)
  match check("ot_scene_get_text_selection", status) {
    Ok(_) => {
      let packed = out[0]
      if packed == 0xffffffffffffffffUL {
        Ok(None)
      } else {
        let start = (packed >> 32).to_uint().reinterpret_as_int()
        let end = packed.to_uint().reinterpret_as_int()
        Ok(Some((start, end)))
      }
    }
    Err(e) => Err(e)
  }
}

///|
/// 读取选中文本（对应 ot_scene_get_selected_text）。
pub fn get_selected_text(context : Context, node : OtHandle) -> Result[String, NativeError] {
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_scene_get_selected_text(context, node, buf, 4096, out)
  match check("ot_scene_get_selected_text", status) {
    Ok(_) => {
      let n = out[0].reinterpret_as_int()
      if n <= 0 {
        Ok("")
      } else {
        Ok(@utf8.decode_lossy(Bytes::from_array(buf[:n]).exact_view()))
      }
    }
    Err(e) => Err(e)
  }
}

///|
/// 节点几何快照（ot_scene_layout 的读取视图）。
pub struct NodeLayout {
  left : Double
  top : Double
  right : Double
  bottom : Double
  width : Double
  height : Double
  screen_x : Double
  screen_y : Double
}

///|
pub fn NodeLayout::left(self : NodeLayout) -> Double {
  self.left
}

///|
pub fn NodeLayout::top(self : NodeLayout) -> Double {
  self.top
}

///|
pub fn NodeLayout::width(self : NodeLayout) -> Double {
  self.width
}

///|
pub fn NodeLayout::height(self : NodeLayout) -> Double {
  self.height
}

///|
/// 读取节点几何（observation 取 OT_LAYOUT_PUBLIC / OT_LAYOUT_PAINT）。
pub fn get_layout(
  context : Context,
  node : OtHandle,
  observation~ : UInt32,
) -> Result[NodeLayout, NativeError] {
  let out : SceneLayout = {
    struct_size: 48,
    abi_version: OT_CONTEXT_ABI_VERSION,
    left: 0.0,
    top: 0.0,
    right: 0.0,
    bottom: 0.0,
    width: 0.0,
    height: 0.0,
    screen_x: 0.0,
    screen_y: 0.0,
  }
  let status = ot_scene_get_layout(context, node, observation, out)
  match check("ot_scene_get_layout", status) {
    Ok(_) =>
      Ok({
        left: out.left.to_double(),
        top: out.top.to_double(),
        right: out.right.to_double(),
        bottom: out.bottom.to_double(),
        width: out.width.to_double(),
        height: out.height.to_double(),
        screen_x: out.screen_x,
        screen_y: out.screen_y,
      })
    Err(e) => Err(e)
  }
}

///|
/// 写终端剪贴板（OSC52，target 0..3；0=clipboard）。
/// 返回写入字节数（0 表示终端不支持或输出被拒）。
pub fn session_copy_to_clipboard(
  context : Context,
  session : OtHandle,
  text~ : String,
  target~ : UInt32 = OT_CLIPBOARD_TARGET_CLIPBOARD,
) -> Result[UInt32, NativeError] {
  let bytes = @utf8.encode(text)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_session_clipboard(
    context,
    session,
    target,
    bytes,
    bytes.length().reinterpret_as_uint(),
    out,
  )
  match check("ot_session_clipboard", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}
