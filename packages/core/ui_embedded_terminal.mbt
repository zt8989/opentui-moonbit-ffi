// TS 兼容层扩展：内嵌终端（对应 @opentui/core 的 EmbeddedTerminalRenderable）。
// 原生 VT 模拟器：宿主喂字节（write），原生维护屏幕状态；渲染走
// CUSTOM 节点 + RENDER_SELF：录制期先把终端屏幕 compose 进节点的
// FrameBuffer，再由既有 DRAW(compose) 录制流把缓冲绘制进帧。

///|
/// 内嵌终端实例。
pub struct EmbeddedTerminal {
  context : Context
  handle : OtHandle
}

///|
/// 光标状态视图。
pub struct TerminalCursorView {
  x : Int
  y : Int
  has_value : Bool
  visible : Bool
  blinking : Bool
  wide_tail : Bool
  style : UInt32
}

///|
pub fn TerminalCursorView::x(self : TerminalCursorView) -> Int {
  self.x
}

///|
pub fn TerminalCursorView::y(self : TerminalCursorView) -> Int {
  self.y
}

///|
pub fn TerminalCursorView::has_value(self : TerminalCursorView) -> Bool {
  self.has_value
}

///|
pub fn TerminalCursorView::visible(self : TerminalCursorView) -> Bool {
  self.visible
}

///|
/// 创建终端（cols×rows 屏幕尺寸，max_scrollback 回滚行上限，0=默认）。
pub fn EmbeddedTerminal::create(
  renderer : Renderer,
  cols~ : Int,
  rows~ : Int,
  max_scrollback~ : Int = 0,
) -> EmbeddedTerminal raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let options : EmbeddedTerminalOptions = {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    cols: cols.reinterpret_as_uint(),
    rows: rows.reinterpret_as_uint(),
    max_scrollback: max_scrollback.reinterpret_as_uint(),
    reserved: 0,
  }
  rethrow_result(
    check("ot_embedded_terminal_create", ot_embedded_terminal_create(renderer.context, options, out)),
  )
  { context: renderer.context, handle: out.to_handle() }
}

///|
/// 销毁终端。
pub fn EmbeddedTerminal::destroy(self : EmbeddedTerminal) -> Unit raise {
  rethrow_result(
    check(
      "ot_embedded_terminal_destroy",
      ot_embedded_terminal_destroy(self.context, self.handle),
    ),
  )
}

///|
/// 喂入字节（子进程输出 / ANSI 序列；上限 1 MiB）。
pub fn EmbeddedTerminal::write(self : EmbeddedTerminal, bytes~ : FixedArray[Byte]) -> Unit raise {
  rethrow_result(
    check(
      "ot_embedded_terminal_write",
      ot_embedded_terminal_write(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 喂入 UTF-8 文本。
pub fn EmbeddedTerminal::write_text(self : EmbeddedTerminal, text~ : String) -> Unit raise {
  let data : FixedArray[Byte] = FixedArray::make(@utf8.encode(text).length(), 0)
  let encoded = @utf8.encode(text)
  for i in 0..<encoded.length() {
    data[i] = encoded[i]
  }
  self.write(bytes=data)
}

///|
/// 调整屏幕尺寸。
pub fn EmbeddedTerminal::resize(self : EmbeddedTerminal, cols~ : Int, rows~ : Int) -> Unit raise {
  rethrow_result(
    check(
      "ot_embedded_terminal_resize",
      ot_embedded_terminal_resize(
        self.context,
        self.handle,
        cols.reinterpret_as_uint(),
        rows.reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 终端命令（INVALIDATE/SCROLL/CLEAR_SELECTION/SET_TRANSPARENT_BACKGROUND）。
pub fn EmbeddedTerminal::command(self : EmbeddedTerminal, command~ : UInt32, argument~ : Int = 0) -> Unit raise {
  rethrow_result(
    check(
      "ot_embedded_terminal_command",
      ot_embedded_terminal_command(
        self.context,
        self.handle,
        command,
        argument,
      ),
    ),
  )
}

///|
/// 设置选区（单元格坐标）。
pub fn EmbeddedTerminal::set_selection(
  self : EmbeddedTerminal,
  start_x~ : Int,
  start_y~ : Int,
  end_x~ : Int,
  end_y~ : Int,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_embedded_terminal_set_selection",
      ot_embedded_terminal_set_selection(
        self.context,
        self.handle,
        start_x.reinterpret_as_uint(),
        start_y.reinterpret_as_uint(),
        end_x.reinterpret_as_uint(),
        end_y.reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 读取选中文本。
pub fn EmbeddedTerminal::get_selected_text(self : EmbeddedTerminal) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(8192, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_embedded_terminal_get_selected_text",
      ot_embedded_terminal_get_selected_text(self.context, self.handle, buf, 8192, out),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 把终端屏幕合成到离屏缓冲（RENDER_SELF 录制期内调用；离屏路径 frame=NULL）。
pub fn EmbeddedTerminal::compose(
  self : EmbeddedTerminal,
  target~ : FrameBuffer,
  x~ : Int = 0,
  y~ : Int = 0,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_embedded_terminal_compose",
      ot_embedded_terminal_compose_offscreen_shim(
        self.context,
        self.handle,
        target.handle,
        x,
        y,
      ),
    ),
  )
}

///|
/// 读取光标状态。
pub fn EmbeddedTerminal::cursor(self : EmbeddedTerminal) -> TerminalCursorView raise {
  let out : EmbeddedTerminalCursor = {
    struct_size: 56,
    abi_version: OT_CONTEXT_ABI_VERSION,
    x: 0,
    y: 0,
    has_value: 0,
    visible: 0,
    blinking: 0,
    wide_tail: 0,
    style: 0,
    color_has_value: 0,
    color_r: 0,
    color_g: 0,
    color_b: 0,
    reserved: 0,
  }
  rethrow_result(
    check(
      "ot_embedded_terminal_cursor_get",
      ot_embedded_terminal_cursor_get(self.context, self.handle, out),
    ),
  )
  {
    x: out.x.reinterpret_as_int(),
    y: out.y.reinterpret_as_int(),
    has_value: out.has_value != 0,
    visible: out.visible != 0,
    blinking: out.blinking != 0,
    wide_tail: out.wide_tail != 0,
    style: out.style,
  }
}

///|
/// 排空终端产生的响应字节（设备属性应答等；上限 1 MiB 保留前缀）。
pub fn EmbeddedTerminal::drain_responses(self : EmbeddedTerminal) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_embedded_terminal_drain_responses",
      ot_embedded_terminal_drain_responses(self.context, self.handle, buf, 4096, out),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 键盘事件编码（action：0=release 1=press 2=repeat；mods 位与 OT_INPUT_MOD_* 一致）。
/// 返回编码出的终端字节序列（写入 write() 即可送达模拟器）。
pub fn EmbeddedTerminal::encode_key(
  self : EmbeddedTerminal,
  key_name~ : String,
  key_text~ : String = "",
  mods~ : UInt32 = 0,
  unshifted_codepoint~ : Int = 0,
  action~ : UInt32 = 1,
) -> String raise {
  fn to_fa(bytes : Bytes) -> FixedArray[Byte] {
    let fa : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
    for i in 0..<bytes.length() {
      fa[i] = bytes[i]
    }
    fa
  }
  let name = to_fa(@utf8.encode(key_name))
  let text = to_fa(@utf8.encode(key_text))
  let out_buf : FixedArray[Byte] = FixedArray::make(64, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_embedded_terminal_encode_key",
      ot_embedded_terminal_encode_key_packed(
        self.context,
        self.handle,
        action,
        mods,
        unshifted_codepoint.reinterpret_as_uint(),
        name,
        name.length().reinterpret_as_uint(),
        text,
        text.length().reinterpret_as_uint(),
        out_buf,
        64,
        out,
      ),
    ),
  )
  decode_bytes(out_buf, out[0].reinterpret_as_int())
}

///|
/// 粘贴编码（括号粘贴模式感知）。
pub fn EmbeddedTerminal::encode_paste(self : EmbeddedTerminal, text~ : String) -> String raise {
  fn paste_fa(bytes : Bytes) -> FixedArray[Byte] {
    let fa : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
    for i in 0..<bytes.length() {
      fa[i] = bytes[i]
    }
    fa
  }
  let input = paste_fa(@utf8.encode(text))
  let out_buf : FixedArray[Byte] = FixedArray::make(input.length() + 16, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_embedded_terminal_encode_paste",
      ot_embedded_terminal_encode_paste(
        self.context,
        self.handle,
        input,
        input.length().reinterpret_as_uint(),
        out_buf,
        out_buf.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  decode_bytes(out_buf, out[0].reinterpret_as_int())
}

///|
/// 焦点事件编码（焦点模式感知；focused=true 进入）。
pub fn EmbeddedTerminal::encode_focus(self : EmbeddedTerminal, focused~ : Bool) -> String raise {
  let out_buf : FixedArray[Byte] = FixedArray::make(16, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_embedded_terminal_encode_focus",
      ot_embedded_terminal_encode_focus(
        self.context,
        self.handle,
        if focused { 1 } else { 0 },
        out_buf,
        16,
        out,
      ),
    ),
  )
  decode_bytes(out_buf, out[0].reinterpret_as_int())
}

///|
/// 注册节点号 → 终端映射（录制期合成用）。
pub fn Renderer::register_embedded_terminal(
  self : Renderer,
  num : UInt32,
  terminal : EmbeddedTerminal,
) -> Unit {
  self.embedded_terminals.set(num, terminal)
}

///|
/// 创建内嵌终端节点：CUSTOM 节点 + RENDER_SELF，绑定给定 FrameBuffer；
/// 录制期先把终端屏幕 compose 进缓冲，再复用 DRAW(compose) 绘制进帧。
pub fn new_embedded_terminal(
  renderer : Renderer,
  terminal : EmbeddedTerminal,
  framebuffer : FrameBuffer,
  width~ : Int,
  height~ : Int,
  position~ : String = "absolute",
  top~ : String = "",
  left~ : String = "",
  z_index~ : Int32 = 0,
) -> Renderable raise {
  let num = renderer.take_node_number()
  let node = new_renderable(
    renderer.context,
    renderer.session,
    CustomNode,
    num~,
    paint=empty_paint(),
  )
  rethrow_result(
    set_hooks(
      renderer.context,
      node.handle,
      flags=OT_SCENE_HOOK_RENDER_SELF,
      generation=1UL,
      initial_width=width.to_double(),
      initial_height=height.to_double(),
    ),
  )
  renderer.framebuffers.set(num, framebuffer)
  renderer.embedded_terminals.set(num, terminal)
  renderer.has_hooks = true
  let builder = StyleBuilder::new()
  builder.set_width(node.handle, Size::parse_lossy(width.to_string()))
  builder.set_height(node.handle, Size::parse_lossy(height.to_string()))
  builder.set_position_type(node.handle, position)
  if top != "" {
    builder.set_position(node.handle, "top", Size::parse_lossy(top))
  }
  if left != "" {
    builder.set_position(node.handle, "left", Size::parse_lossy(left))
  }
  let _ = flush_styles_of(renderer.context, builder)
  if z_index != 0 {
    node.set_z_index_internal(z_index)
  }
  node
}
