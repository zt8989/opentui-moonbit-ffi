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
  // 钩子 generation 非 0；initial 尺寸在首次布局前提供基线
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

