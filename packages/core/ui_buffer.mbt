// TS 兼容层扩展：FrameBuffer（对应 @opentui/core 的 FrameBufferRenderable）。
//
// 模型：CUSTOM 场景节点 + RENDER_SELF 钩子 + 独立离屏 buffer。渲染时
// Renderer::render() 走 step 循环：原生返回 RECORD 请求，宿主回放
// SLOT + DRAW(离屏 buffer) 录制流，原生把 buffer 内容按节点几何绘制进帧。
//
// 注意：draw_text 的宽字符（CJK/emoji/grapheme）宽度测量在原生层完成。

///|
/// 离屏像素/字符缓冲（owned，独立于 Session）。
pub struct FrameBuffer {
  context : Context
  handle : OtHandle
  width : UInt32
  height : UInt32
}

///|
/// 创建离屏缓冲。width*height 不得超过 Context 的 render_cells_max。
pub fn FrameBuffer::create(
  renderer : Renderer,
  width~ : UInt32,
  height~ : UInt32,
  respect_alpha~ : Bool = false,
) -> FrameBuffer raise {
  let handle = rethrow_result(
    create_buffer(renderer.context, width~, height~, respect_alpha~),
  )
  { context: renderer.context, handle, width, height, }
}

///|
fn[T] rethrow_result(r : Result[T, NativeError]) -> T raise {
  match r {
    Ok(v) => v
    Err(e) => raise Failure(e.to_string())
  }
}

///|
/// 清屏（CLEAR：空格 + 给定背景）。
pub fn FrameBuffer::clear(
  self : FrameBuffer,
  background~ : String,
) -> Unit raise {
  rethrow_result(
    buffer_clear(
      self.context,
      self.handle,
      background=parse_color_lossy(background),
    ),
  )
}

///|
/// 填充矩形。
pub fn FrameBuffer::fill(
  self : FrameBuffer,
  x~ : Int32,
  y~ : Int32,
  width~ : UInt32,
  height~ : UInt32,
  background~ : String,
) -> Unit raise {
  rethrow_result(
    buffer_fill(
      self.context,
      self.handle,
      x~,
      y~,
      width~,
      height~,
      background=parse_color_lossy(background),
    ),
  )
}

///|
/// 绘制文本（宽字符宽度由原生测量；无背景时保留目标像素背景）。
pub fn FrameBuffer::draw_text(
  self : FrameBuffer,
  text~ : String,
  x~ : Int32,
  y~ : Int32,
  fg~ : String,
  bg~ : String? = None,
  attributes~ : UInt32 = 0,
) -> Unit raise {
  rethrow_result(
    buffer_draw_text(
      self.context,
      self.handle,
      text~,
      x~,
      y~,
      foreground=parse_color_lossy(fg),
      background=match bg {
        Some(c) => Some(parse_color_lossy(c))
        None => None
      },
      attributes~,
    ),
  )
}

///|
/// 写单个单元格。
pub fn FrameBuffer::draw_cell(
  self : FrameBuffer,
  x~ : Int32,
  y~ : Int32,
  character~ : UInt32,
  fg~ : String,
  bg~ : String,
  attributes~ : UInt32 = 0,
) -> Unit raise {
  rethrow_result(
    buffer_draw_cell(
      self.context,
      self.handle,
      x~,
      y~,
      character~,
      foreground=parse_color_lossy(fg),
      background=parse_color_lossy(bg),
      attributes~,
    ),
  )
}

///|
/// 取节点关联的离屏缓冲（new_framebuffer 创建的节点）。
pub fn framebuffer_of(renderer : Renderer, node : Renderable) -> FrameBuffer raise {
  match renderer.framebuffers.get(node.num) {
    Some(fb) => fb
    None => raise Failure("node has no framebuffer (not created by new_framebuffer)")
  }
}

///|
/// 释放离屏缓冲（之后节点绘制为空）。可选调用：destroy() 会随 Context 释放。
pub fn FrameBuffer::destroy(self : FrameBuffer) -> Unit {
  let _ = destroy_buffer(self.context, self.handle)
}

///|
/// 创建 FrameBuffer 节点（对应 new FrameBufferRenderable(renderer, {...})）。
/// CUSTOM 节点 + RENDER_SELF 钩子：渲染时把离屏缓冲绘制在节点几何位置。
/// 布局参数与 new_box 对齐（absolute 定位 + top/left 最常用）。
pub fn new_framebuffer(
  renderer : Renderer,
  width~ : UInt32,
  height~ : UInt32,
  respect_alpha~ : Bool = false,
  position~ : String = "absolute",
  top~ : String = "",
  left~ : String = "",
  z_index~ : Int32 = 0,
  opacity~ : Double = 1.0,
  background~ : String = "transparent",
) -> Renderable raise {
  let num = renderer.take_node_number()
  let node = new_renderable(
    renderer.context,
    renderer.session,
    CustomNode,
    num~,
    paint=empty_paint(),
  )
  // 钩子 generation 全局递增（原生用它排序/识别阶段）；
  // RENDER_SELF 必须伴随 RENDER_AFTER（对齐 TS 的 nativeFlags 逻辑）
  renderer.hook_gen = renderer.hook_gen + 1
  rethrow_result(
    set_hooks(
      renderer.context,
      node.handle,
      flags=OT_SCENE_HOOK_RENDER_SELF.lor(OT_SCENE_HOOK_RENDER_AFTER),
      generation=renderer.hook_gen,
      initial_width=width.to_double(),
      initial_height=height.to_double(),
    ),
  )
  let buffer = FrameBuffer::create(renderer, width~, height~, respect_alpha~)
  renderer.framebuffers.set(num, buffer)
  renderer.has_hooks = true
  // 绘制属性与布局样式（一次 flush）
  node.set_background_internal(background)
  node.set_opacity_internal(opacity)
  node.set_z_index_internal(z_index)
  let builder = StyleBuilder::new()
  builder.set_width(
    node.handle,
    Size::parse_lossy(width.reinterpret_as_int().to_string()),
  )
  builder.set_height(
    node.handle,
    Size::parse_lossy(height.reinterpret_as_int().to_string()),
  )
  builder.set_position_type(node.handle, position)
  if top != "" {
    builder.set_position(node.handle, "top", Size::parse_lossy(top))
  }
  if left != "" {
    builder.set_position(node.handle, "left", Size::parse_lossy(left))
  }
  let _ = flush_styles_of(renderer.context, builder)
  node
}


///|
/// 调整离屏缓冲尺寸（split footer 高度变化等场景）。
/// 返回新的 FrameBuffer 视图（原记录尺寸字段不可变）。
pub fn FrameBuffer::resize(
  self : FrameBuffer,
  renderer : Renderer,
  width~ : UInt32,
  height~ : UInt32,
) -> FrameBuffer raise {
  let _ = renderer
  rethrow_result(
    buffer_resize(self.context, self.handle, width~, height~),
  )
  { context: self.context, handle: self.handle, width, height }
}

///|
/// 把 Float 数组序列化为小端 f32 字节缓冲（grayscale 传参用）。
pub fn floats_to_bytes(values : FixedArray[Float]) -> FixedArray[Byte] {
  let buf : FixedArray[Byte] = FixedArray::make(values.length() * 4, 0)
  for i, v in values {
    let bits : Int = v.reinterpret_as_int()
    let base = i * 4
    buf[base] = (bits & 0xFF).to_byte()
    buf[base + 1] = ((bits >> 8) & 0xFF).to_byte()
    buf[base + 2] = ((bits >> 16) & 0xFF).to_byte()
    buf[base + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  buf
}

///|
/// 绘制灰度采样图（intensity 0..1，宽×高个采样；超采样变体传
/// supersample=true，采样图为放大后的格网）。fg/bg 依据强度插值。
pub fn FrameBuffer::draw_grayscale(
  self : FrameBuffer,
  intensities~ : FixedArray[Float],
  x~ : Int32 = 0,
  y~ : Int32 = 0,
  width~ : UInt32,
  height~ : UInt32,
  fg~ : String = "#ffffff",
  bg~ : String = "#000000",
  supersample~ : Bool = false,
) -> Unit raise {
  let data = floats_to_bytes(intensities)
  let fg_color = parse_color_lossy(fg)
  let bg_color = parse_color_lossy(bg)
  rethrow_result(
    check(
      "ot_buffer_draw_grayscale",
      ot_buffer_draw_grayscale_shim(
        self.context,
        self.handle,
        data,
        data.length().reinterpret_as_uint() / 4,
        x,
        y,
        width,
        height,
        pack_u16x2(fg_color.0, fg_color.1),
        pack_u16x2(fg_color.2, fg_color.3),
        pack_u16x2(bg_color.0, bg_color.1),
        pack_u16x2(bg_color.2, bg_color.3),
        if supersample { 1 } else { 0 },
      ),
    ),
  )
}

///|
/// 绘制打包像素（格式由原生约定，见 opentui.h 的 draw_packed）。
pub fn FrameBuffer::draw_packed(
  self : FrameBuffer,
  data~ : FixedArray[Byte],
  x~ : Int32 = 0,
  y~ : Int32 = 0,
  width~ : UInt32,
  height~ : UInt32,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_buffer_draw_packed",
      ot_buffer_draw_packed_shim(
        self.context,
        self.handle,
        data,
        data.length().reinterpret_as_uint(),
        x,
        y,
        width,
        height,
      ),
    ),
  )
}

///|
/// 绘制超采样像素数据（format/stride 按原生约定）。
pub fn FrameBuffer::draw_supersample(
  self : FrameBuffer,
  data~ : FixedArray[Byte],
  x~ : Int32 = 0,
  y~ : Int32 = 0,
  format~ : UInt32 = 0,
  stride~ : UInt32 = 0,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_buffer_draw_supersample",
      ot_buffer_draw_supersample_shim(
        self.context,
        self.handle,
        data,
        data.length().reinterpret_as_uint(),
        x,
        y,
        format,
        stride,
      ),
    ),
  )
}

///|
/// Unicode 资源（字素池：宽度测量 + 逐字素绘制记录）。
pub struct UnicodeResource {
  context : Context
  handle : OtHandle
}

///|
/// 一个绘制记录：display 宽度 + 字素池字符。
pub struct UnicodeCharView {
  width : Int
  character : UInt32
}

///|
pub fn UnicodeCharView::width(self : UnicodeCharView) -> Int {
  self.width
}

///|
pub fn UnicodeCharView::character(self : UnicodeCharView) -> UInt32 {
  self.character
}

///|
/// 创建 Unicode 资源（UTF-8 文本；width_method 同 OT_WIDTH_METHOD_*）。
pub fn UnicodeResource::create(
  renderer : Renderer,
  text~ : String,
  width_method~ : UInt32 = OT_WIDTH_METHOD_WCWIDTH,
) -> UnicodeResource raise {
  let encoded = @utf8.encode(text)
  let bytes : FixedArray[Byte] = FixedArray::make(encoded.length(), 0)
  for i in 0..<encoded.length() {
    bytes[i] = encoded[i]
  }
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_unicode_create",
      ot_unicode_create(
        renderer.context,
        bytes,
        bytes.length().reinterpret_as_uint(),
        width_method,
        out,
      ),
    ),
  )
  { context: renderer.context, handle: out.to_handle() }
}

///|
/// 销毁资源。
pub fn UnicodeResource::destroy(self : UnicodeResource) -> Unit raise {
  rethrow_result(
    check("ot_unicode_destroy", ot_unicode_destroy(self.context, self.handle)),
  )
}

///|
/// 读取字素记录（宽度 + 池内字符）。
pub fn UnicodeResource::chars(self : UnicodeResource) -> Array[UnicodeCharView] raise {
  let buf : FixedArray[Byte] = FixedArray::make(1024 * 8, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_unicode_get",
      ot_unicode_get(self.context, self.handle, buf, 1024, out),
    ),
  )
  let result : Array[UnicodeCharView] = []
  let count = out[0].reinterpret_as_int()
  let mut i = 0
  while i < count {
    let base = i * 8
    let u32_at = fn(off : Int) -> UInt32 {
      buf[off].to_uint() |
      (buf[off + 1].to_uint() << 8) |
      (buf[off + 2].to_uint() << 16) |
      (buf[off + 3].to_uint() << 24)
    }
    result.push({ width: u32_at(base).reinterpret_as_int(), character: u32_at(base + 4) })
    i += 1
  }
  result
}

///|
/// 把 Unicode 资源的第 index 个字素画到缓冲上。
pub fn FrameBuffer::draw_unicode(
  self : FrameBuffer,
  unicode : UnicodeResource,
  index~ : Int,
  x~ : Int32 = 0,
  y~ : Int32 = 0,
  fg~ : String = "#ffffff",
  bg~ : String = "#000000",
  attributes~ : UInt32 = 0,
) -> Unit raise {
  let fg_color = parse_color_lossy(fg)
  let bg_color = parse_color_lossy(bg)
  rethrow_result(
    check(
      "ot_buffer_draw_unicode",
      ot_buffer_draw_unicode_shim(
        self.context,
        self.handle,
        unicode.handle,
        index.reinterpret_as_uint(),
        x,
        y,
        pack_u16x2(fg_color.0, fg_color.1),
        pack_u16x2(fg_color.2, fg_color.3),
        pack_u16x2(bg_color.0, bg_color.1),
        pack_u16x2(bg_color.2, bg_color.3),
        attributes,
      ),
    ),
  )
}
