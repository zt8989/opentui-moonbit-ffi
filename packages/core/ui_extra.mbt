// TS 兼容层扩展：styled text（富文本混排）、slider 节点、鼠标事件与命中测试。

///|
/// 一段富文本：内容 + 颜色 + 属性位（对应 TS 的 StyledText chunk）。
/// url 非空时该段是超链接（对应 TS 的 link(url)(text)）。
pub struct Chunk {
  text : String
  fg : String
  bg : String
  attributes : UInt32
  url : String
}

///|
pub fn Chunk::make(
  text~ : String,
  fg~ : String = "inherit",
  bg~ : String = "transparent",
  attributes~ : UInt32 = 0,
  url~ : String = "",
) -> Chunk {
  { text, fg, bg, attributes, url, }
}

///|
/// 编码一条 ot_styled_text_chunk（48 字节小端）。
fn encode_styled_chunk(
  buf : FixedArray[Byte],
  offset : Int32,
  byte_count : UInt32,
  flags : UInt32,
  fg : RgbaColor,
  bg : RgbaColor,
  attributes : UInt32,
  link_offset : UInt32,
  link_byte_count : UInt32,
) -> Unit {
  let put32 = fn(off : Int32, v : UInt32) -> Unit {
    for i in 0..<4 {
      buf[offset + off + i] = ((v >> (i * 8)) & 0xff)
        .reinterpret_as_int()
        .to_byte()
    }
  }
  put32(0, 48)
  put32(4, OT_CONTEXT_ABI_VERSION)
  put32(8, byte_count)
  put32(12, flags)
  put32(16, pack_u16x2(fg.0, fg.1))
  put32(20, pack_u16x2(fg.2, fg.3))
  put32(24, pack_u16x2(bg.0, bg.1))
  put32(28, pack_u16x2(bg.2, bg.3))
  put32(32, attributes)
  put32(36, 0)
  put32(40, link_offset)
  put32(44, link_byte_count)
}

///|
/// 提交富文本（对应 TS 的 textNode.chunks = [...]）。
/// fg 为 "inherit" 的段继承节点前景色。
pub fn Renderable::set_styled_chunks(
  self : Renderable,
  chunks : Array[Chunk],
) -> Unit raise {
  let mut total_bytes = 0
  let mut url_bytes = 0
  let encoded : Array[
    (Bytes, RgbaColor, RgbaColor, UInt32, UInt32, UInt32, UInt32, UInt32),
  ] = []
  for chunk in chunks {
    let bytes = @utf8.encode(chunk.text)
    let len = bytes.length().reinterpret_as_uint()
    let fg = if chunk.fg == "inherit" {
      self.fg
    } else {
      parse_color_lossy(chunk.fg)
    }
    let bg : RgbaColor = if chunk.bg == "inherit" || chunk.bg == "transparent" {
      (0, 0, 0, 0)
    } else {
      parse_color_lossy(chunk.bg)
    }
    // flags 只接受 FOREGROUND/BACKGROUND/LINK；attributes 走独立字段（bits 0..7）
    let mut flags = OT_SCENE_TEXT_FOREGROUND.lor(
      if bg.3 > 0 {
        OT_SCENE_TEXT_BACKGROUND
      } else {
        0
      },
    )
    // url 表是所有 URL 字节的连续拼接，chunk 记录自己的区间
    let mut link_offset : UInt32 = 0
    let mut link_len : UInt32 = 0
    if chunk.url != "" {
      flags = flags.lor(OT_SCENE_TEXT_LINK)
      link_offset = url_bytes.reinterpret_as_uint()
      link_len = @utf8.encode(chunk.url).length().reinterpret_as_uint()
      url_bytes += link_len.reinterpret_as_int()
    }
    encoded.push(
      (bytes, fg, bg, flags, chunk.attributes, len, link_offset, link_len),
    )
    total_bytes += len.reinterpret_as_int()
  }
  let content : FixedArray[Byte] = FixedArray::make(
    if total_bytes > 0 {
      total_bytes
    } else {
      1
    },
    0,
  )
  let chunk_buf : FixedArray[Byte] = FixedArray::make(encoded.length() * 48, 0)
  let url_buf : FixedArray[Byte] = FixedArray::make(
    if url_bytes > 0 {
      url_bytes
    } else {
      1
    },
    0,
  )
  let mut offset = 0
  let mut url_offset = 0
  for i, item in encoded {
    let (bytes, fg, bg, flags, attrs, len, link_off, link_len) = item
    let n = len.reinterpret_as_int()
    for j in 0..<n {
      content[offset + j] = bytes[j]
    }
    if link_len > 0 {
      let url = @utf8.encode(chunks[i].url)
      for j in 0..<url.length() {
        url_buf[url_offset + j] = url[j]
      }
    }
    encode_styled_chunk(
      chunk_buf,
      i * 48,
      len,
      flags,
      fg,
      bg,
      attrs,
      link_off,
      link_len,
    )
    offset += n
    url_offset += link_len.reinterpret_as_int()
  }
  self.content = {
    let buf = StringBuilder(size_hint=total_bytes)
    for chunk in chunks {
      buf.write_string(chunk.text)
    }
    buf.to_string()
  }
  let status = ot_scene_set_styled_text(
    self.context,
    self.handle,
    content,
    total_bytes.reinterpret_as_uint(),
    chunk_buf,
    encoded.length().reinterpret_as_uint(),
    url_buf,
    url_bytes.reinterpret_as_uint(),
  )
  rethrow(check("ot_scene_set_styled_text", status))
}

///|
/// 鼠标事件（对应 TS 的 MouseEvent）。
pub struct MouseEvent {
  action : UInt32
  button : UInt32
  x : UInt32
  y : UInt32
}

///|
pub fn MouseEvent::is_down(self : MouseEvent) -> Bool {
  self.action == OT_INPUT_MOUSE_DOWN
}

///|
pub fn MouseEvent::is_up(self : MouseEvent) -> Bool {
  self.action == OT_INPUT_MOUSE_UP
}

///|
pub fn MouseEvent::is_drag(self : MouseEvent) -> Bool {
  self.action == OT_INPUT_MOUSE_DRAG
}

///|
pub fn MouseEvent::is_move(self : MouseEvent) -> Bool {
  self.action == OT_INPUT_MOUSE_MOVE
}

///|
pub fn MouseEvent::is_scroll(self : MouseEvent) -> Bool {
  self.action == OT_INPUT_MOUSE_SCROLL
}

///|
pub fn MouseEvent::x(self : MouseEvent) -> UInt32 {
  self.x
}

///|
pub fn MouseEvent::y(self : MouseEvent) -> UInt32 {
  self.y
}

///|
pub fn MouseEvent::button(self : MouseEvent) -> UInt32 {
  self.button
}

///|
/// 命中测试：返回 (x, y) 处最上层节点的公开节点号（无命中返回 0）。
/// 需要先 enable_mouse 并渲染过至少一帧。
pub fn Renderer::hit_test(
  self : Renderer,
  x : UInt32,
  y : UInt32,
) -> Result[UInt32, NativeError] {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_scene_hit_test(
    self.context,
    self.session,
    x.reinterpret_as_int(),
    y.reinterpret_as_int(),
    out,
  )
  match check("ot_scene_hit_test", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}

///|
/// 创建 slider 节点（对应 new SliderRenderable(renderer, {...})）。
pub fn new_slider(
  renderer : Renderer,
  orientation~ : String = "horizontal",
  min~ : Double = 0.0,
  max~ : Double = 100.0,
  value~ : Double = 0.0,
  viewport_size~ : Double = 0.0,
  fg~ : String = "white",
  bg~ : String = "transparent",
  width~ : String = "20",
  height~ : String = "1",
) -> Renderable raise {
  let node = new_renderable(
    renderer.context,
    renderer.session,
    SliderNode,
    num=renderer.take_node_number(),
    paint=empty_paint(),
  )
  let builder = StyleBuilder::new()
  builder.set_width(node.handle, Size::parse_lossy(width))
  builder.set_height(node.handle, Size::parse_lossy(height))
  let _ = flush_styles_of(renderer.context, builder)
  let _ = node.set_slider_options(
    orientation~,
    min~,
    max~,
    value~,
    viewport_size~,
    fg~,
    bg~,
  )
  node
}

///|
/// 更新 slider 的值/范围（对应 slider.value = v）。
pub fn Renderable::set_slider_value(
  self : Renderable,
  value~ : Double,
  min~ : Double = 0.0,
  max~ : Double = 100.0,
) -> Result[Unit, NativeError] {
  self.set_slider_options(value~, min~, max~)
}

///|
fn Renderable::set_slider_options(
  self : Renderable,
  orientation~ : String = "horizontal",
  min~ : Double = 0.0,
  max~ : Double = 100.0,
  value~ : Double = 0.0,
  viewport_size~ : Double = 0.0,
  fg~ : String = "white",
  bg~ : String = "transparent",
) -> Result[Unit, NativeError] {
  let fg_color = parse_color_lossy(fg)
  let bg_color = parse_color_lossy(bg)
  let fg = pack_rgba(fg_color)
  let bg = pack_rgba(bg_color)
  let options : SliderOptions = {
    struct_size: 64,
    abi_version: OT_CONTEXT_ABI_VERSION,
    orientation: if orientation == "vertical" {
      OT_SLIDER_ORIENTATION_VERTICAL
    } else {
      OT_SLIDER_ORIENTATION_HORIZONTAL
    },
    reserved: 0,
    min,
    max,
    value,
    viewport_size,
    foreground01: fg.0,
    foreground23: fg.1,
    background01: bg.0,
    background23: bg.1,
  }
  let status = ot_scene_set_slider(self.context, self.handle, options)
  match check("ot_scene_set_slider", status) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}
