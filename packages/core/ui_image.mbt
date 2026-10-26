// TS 兼容层扩展：图像（对应 @opentui/core 的 ImageRenderable 与 native
// image 管线）。Image 持解码后的像素资源，OT_SCENE_IMAGE 节点绑定后由
// 原生按 fit/protocol 渲染（kitty/sixel/blocks；blocks 在任意终端可用）。

///|
/// 解码后的图像资源。
pub struct Image {
  context : Context
  handle : OtHandle
}

///|
/// 图像信息视图。
pub struct ImageInfoView {
  width : Int
  height : Int
  source_width : Int
  source_height : Int
  format : UInt32
  has_alpha : Bool
}

///|
pub fn ImageInfoView::width(self : ImageInfoView) -> Int {
  self.width
}

///|
pub fn ImageInfoView::height(self : ImageInfoView) -> Int {
  self.height
}

///|
pub fn ImageInfoView::source_width(self : ImageInfoView) -> Int {
  self.source_width
}

///|
pub fn ImageInfoView::source_height(self : ImageInfoView) -> Int {
  self.source_height
}

///|
pub fn ImageInfoView::format(self : ImageInfoView) -> UInt32 {
  self.format
}

///|
pub fn ImageInfoView::has_alpha(self : ImageInfoView) -> Bool {
  self.has_alpha
}

///|
/// 探测编码字节（PNG/JPEG/WebP/GIF 头），不解码像素。
pub fn inspect_image(renderer : Renderer, bytes~ : FixedArray[Byte]) -> ImageInfoView raise {
  let out : ImageInfo = {
    width: 0,
    height: 0,
    source_width: 0,
    source_height: 0,
    format: 0,
    color_status: 0,
    orientation: 0,
    has_alpha: 0,
  }
  rethrow_result(
    check(
      "ot_image_inspect",
      ot_image_inspect(renderer.context, bytes, bytes.length().to_uint64(), out),
    ),
  )
  image_info_view_of(out)
}

///|
fn image_info_view_of(out : ImageInfo) -> ImageInfoView {
  {
    width: out.width.reinterpret_as_int(),
    height: out.height.reinterpret_as_int(),
    source_width: out.source_width.reinterpret_as_int(),
    source_height: out.source_height.reinterpret_as_int(),
    format: out.format,
    has_alpha: out.has_alpha != 0,
  }
}

///|
fn image_of(renderer : Renderer, out : HandleOut) -> Image raise {
  { context: renderer.context, handle: out.to_handle() }
}

///|
/// 解码编码字节（PNG/JPEG/WebP/GIF）。
pub fn Image::decode(renderer : Renderer, bytes~ : FixedArray[Byte]) -> Image raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_decode",
      ot_image_decode(renderer.context, bytes, bytes.length().to_uint64(), out),
    ),
  )
  image_of(renderer, out)
}

///|
/// 从 RGBA8 像素创建（stride=0 表示 width*4 紧密排列）。
pub fn Image::from_pixels(
  renderer : Renderer,
  pixels~ : FixedArray[Byte],
  width~ : Int,
  height~ : Int,
  stride~ : Int = 0,
  bgra~ : Bool = false,
  opaque~ : Bool = false,
) -> Image raise {
  let actual_stride = if stride > 0 { stride } else { width * 4 }
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_create_pixels",
      ot_image_create_pixels(
        renderer.context,
        pixels,
        pixels.length().to_uint64(),
        width.reinterpret_as_uint(),
        height.reinterpret_as_uint(),
        actual_stride.reinterpret_as_uint(),
        if bgra { OT_IMAGE_FORMAT_BGRA8 } else { OT_IMAGE_FORMAT_RGBA8 },
        if opaque { OT_IMAGE_ALPHA_OPAQUE } else { OT_IMAGE_ALPHA_STRAIGHT },
        out,
      ),
    ),
  )
  image_of(renderer, out)
}

///|
/// 覆写像素（尺寸不变）。
pub fn Image::update_pixels(
  self : Image,
  pixels~ : FixedArray[Byte],
  stride~ : Int = 0,
) -> Unit raise {
  let info = self.get_info()
  let actual_stride = if stride > 0 { stride } else { info.width * 4 }
  rethrow_result(
    check(
      "ot_image_update_pixels",
      ot_image_update_pixels(
        self.context,
        self.handle,
        pixels,
        pixels.length().to_uint64(),
        actual_stride.reinterpret_as_uint(),
        OT_IMAGE_FORMAT_RGBA8,
        OT_IMAGE_ALPHA_STRAIGHT,
      ),
    ),
  )
}

///|
/// 释放公开句柄（节点/已绘制内容保留存储）。
pub fn Image::destroy(self : Image) -> Unit raise {
  rethrow_result(check("ot_image_destroy", ot_image_destroy(self.context, self.handle)))
}

///|
/// 读取信息。
pub fn Image::get_info(self : Image) -> ImageInfoView raise {
  let out : ImageInfo = {
    width: 0,
    height: 0,
    source_width: 0,
    source_height: 0,
    format: 0,
    color_status: 0,
    orientation: 0,
    has_alpha: 0,
  }
  rethrow_result(check("ot_image_get_info", ot_image_get_info(self.context, self.handle, out)))
  image_info_view_of(out)
}

///|
/// 缩放到 width×height（返回新图像）。
pub fn Image::resize(self : Image, width~ : Int, height~ : Int, filter~ : UInt32 = OT_IMAGE_FILTER_DEFAULT) -> Image raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_resize",
      ot_image_resize(
        self.context,
        self.handle,
        width.reinterpret_as_uint(),
        height.reinterpret_as_uint(),
        filter,
        out,
      ),
    ),
  )
  { context: self.context, handle: out.to_handle() }
}

///|
/// 裁剪矩形区域（返回新图像）。
pub fn Image::extract(self : Image, left~ : Int, top~ : Int, width~ : Int, height~ : Int) -> Image raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_extract",
      ot_image_extract(
        self.context,
        self.handle,
        left.reinterpret_as_uint(),
        top.reinterpret_as_uint(),
        width.reinterpret_as_uint(),
        height.reinterpret_as_uint(),
        out,
      ),
    ),
  )
  { context: self.context, handle: out.to_handle() }
}

///|
/// 四边扩展，background 为 RGBA8 四字节。
pub fn Image::extend_borders(
  self : Image,
  top~ : Int,
  right~ : Int,
  bottom~ : Int,
  left~ : Int,
  background~ : (Int, Int, Int, Int),
) -> Image raise {
  let bg : FixedArray[Byte] = FixedArray::make(4, 0)
  bg[0] = background.0.to_byte()
  bg[1] = background.1.to_byte()
  bg[2] = background.2.to_byte()
  bg[3] = background.3.to_byte()
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_extend",
      ot_image_extend(
        self.context,
        self.handle,
        top.reinterpret_as_uint(),
        right.reinterpret_as_uint(),
        bottom.reinterpret_as_uint(),
        left.reinterpret_as_uint(),
        bg,
        out,
      ),
    ),
  )
  { context: self.context, handle: out.to_handle() }
}

///|
/// 旋转/翻转（返回新图像）。
pub fn Image::transform(self : Image, operation~ : UInt32) -> Image raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_transform",
      ot_image_transform(self.context, self.handle, operation, out),
    ),
  )
  { context: self.context, handle: out.to_handle() }
}

///|
/// 把 overlay 合成到 base 的 (left,top)（返回新图像；opacity 0..255）。
pub fn Image::composite(
  base : Image,
  overlay~ : Image,
  left~ : Int,
  top~ : Int,
  blend~ : UInt32 = OT_IMAGE_BLEND_SOURCE_OVER,
  opacity~ : Int = 255,
) -> Image raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_image_composite",
      ot_image_composite(
        base.context,
        base.handle,
        overlay.handle,
        left,
        top,
        blend,
        opacity.to_byte(),
        out,
      ),
    ),
  )
  { context: base.context, handle: out.to_handle() }
}

///|
/// 读取 RGBA8 像素到 destination。
pub fn Image::copy_pixels(self : Image, destination~ : FixedArray[Byte], stride~ : Int = 0) -> Unit raise {
  let info = self.get_info()
  let actual_stride = if stride > 0 { stride } else { info.width * 4 }
  rethrow_result(
    check(
      "ot_image_copy_pixels",
      ot_image_copy_pixels(
        self.context,
        self.handle,
        destination,
        destination.length().to_uint64(),
        actual_stride.reinterpret_as_uint(),
        OT_IMAGE_FORMAT_RGBA8,
      ),
    ),
  )
}

///|
/// 导出 PNG 编码字节。
pub fn Image::copy_png(self : Image) -> FixedArray[Byte] raise {
  // 零容量查询精确大小，再分配复制
  let out_size : FixedArray[UInt64] = FixedArray::make(1, 0UL)
  rethrow_result(
    check(
      "ot_image_copy_png",
      ot_image_copy_png(self.context, self.handle, FixedArray::make(1, 0), 0UL, out_size),
    ),
  )
  let n = out_size[0]
  let buf : FixedArray[Byte] = FixedArray::make(n.to_int(), 0)
  let out2 : FixedArray[UInt64] = FixedArray::make(1, 0UL)
  rethrow_result(
    check(
      "ot_image_copy_png",
      ot_image_copy_png(self.context, self.handle, buf, n, out2),
    ),
  )
  buf
}

///|
/// 创建图像节点（对应 new ImageRenderable(...)）：OT_SCENE_IMAGE 节点绑定
/// 图像，原生按 fit/protocol 渲染。protocol 缺省 AUTO（探测终端能力）；
/// blocks 兜底在任意终端/文件输出可用。
pub fn new_image(
  renderer : Renderer,
  image : Image,
  width~ : String = "auto",
  height~ : String = "auto",
  fit~ : UInt32 = OT_IMAGE_FIT,
  protocol~ : UInt32 = OT_IMAGE_PROTOCOL_AUTO,
  position~ : String = "relative",
  top~ : String = "",
  left~ : String = "",
  z_index~ : Int32 = 0,
) -> Renderable raise {
  let num = renderer.take_node_number()
  let node = new_renderable(
    renderer.context,
    renderer.session,
    ImageNode,
    num~,
    paint=empty_paint(),
  )
  rethrow_result(
    check(
      "ot_scene_set_image",
      ot_scene_set_image_shim(renderer.context, node.handle, image.handle, fit, protocol),
    ),
  )
  let builder = StyleBuilder::new()
  builder.set_width(node.handle, Size::parse_lossy(width))
  builder.set_height(node.handle, Size::parse_lossy(height))
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

///|
/// 存储终端单元格与像素尺寸（native fit 计算用；全零清除）。
pub fn Renderer::set_image_resolution(
  self : Renderer,
  terminal_width~ : Int,
  terminal_height~ : Int,
  pixel_width~ : Int,
  pixel_height~ : Int,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_session_set_image_resolution",
      ot_session_set_image_resolution(
        self.context,
        self.session,
        terminal_width.reinterpret_as_uint(),
        terminal_height.reinterpret_as_uint(),
        pixel_width.reinterpret_as_uint(),
        pixel_height.reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// Kitty 图像传输状态视图。
pub struct KittyTransportView {
  requested : UInt32
  effective : UInt32
  file_state : UInt32
  fallback : UInt32
  pending_files : Int
  pending_bytes : Int
}

///|
pub fn KittyTransportView::requested(self : KittyTransportView) -> UInt32 {
  self.requested
}

///|
pub fn KittyTransportView::effective(self : KittyTransportView) -> UInt32 {
  self.effective
}

///|
pub fn KittyTransportView::file_state(self : KittyTransportView) -> UInt32 {
  self.file_state
}

///|
pub fn KittyTransportView::fallback(self : KittyTransportView) -> UInt32 {
  self.fallback
}

///|
pub fn KittyTransportView::pending_files(self : KittyTransportView) -> Int {
  self.pending_files
}

///|
pub fn KittyTransportView::pending_bytes(self : KittyTransportView) -> Int {
  self.pending_bytes
}

///|
/// 设置 Kitty 图像传输模式（0=raw 1=zlib 2=file）。
pub fn Renderer::set_kitty_transport(self : Renderer, mode~ : UInt32) -> Unit raise {
  rethrow_result(
    check(
      "ot_session_set_kitty_image_transport",
      ot_session_set_kitty_image_transport(self.context, self.session, mode),
    ),
  )
}

///|
/// 读取 Kitty 图像传输状态。
pub fn Renderer::get_kitty_transport(self : Renderer) -> KittyTransportView raise {
  let out : KittyTransportStatus = {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    requested: 0,
    effective: 0,
    file_state: 0,
    fallback: 0,
    pending_files: 0,
    pending_bytes: 0,
  }
  rethrow_result(
    check(
      "ot_session_get_kitty_image_transport",
      ot_session_get_kitty_image_transport(self.context, self.session, out),
    ),
  )
  {
    requested: out.requested,
    effective: out.effective,
    file_state: out.file_state,
    fallback: out.fallback,
    pending_files: out.pending_files.reinterpret_as_int(),
    pending_bytes: out.pending_bytes.reinterpret_as_int(),
  }
}

///|
/// 轮询 Kitty 文件传输（file 模式下定期调用；返回是否需要再次轮询）。
pub fn Renderer::poll_kitty_transport(self : Renderer, now_ns~ : UInt64) -> Bool raise {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_session_poll_kitty_image_transport",
      ot_session_poll_kitty_image_transport(self.context, self.session, now_ns, out),
    ),
  )
  out[0] != 0
}

///|
/// 取消 Kitty 图像传输（failed=true 上报失败）。
pub fn Renderer::cancel_kitty_transport(self : Renderer, failed~ : Bool = false) -> Unit raise {
  rethrow_result(
    check(
      "ot_session_cancel_kitty_image_transport",
      ot_session_cancel_kitty_image_transport(
        self.context,
        self.session,
        if failed { 1 } else { 0 },
      ),
    ),
  )
}

///|
/// 处理终端的 Kitty 图像应答字节（返回 0=忽略 1=已消费 2=已消费需重传）。
pub fn Renderer::process_kitty_reply(self : Renderer, bytes~ : FixedArray[Byte]) -> Int raise {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_session_process_kitty_image_reply",
      ot_session_process_kitty_image_reply(
        self.context,
        self.session,
        bytes,
        bytes.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 重新绑定节点图像（对应 imageRenderable.image = ...）。
pub fn Renderable::set_image(
  self : Renderable,
  image : Image,
  fit~ : UInt32 = OT_IMAGE_FIT,
  protocol~ : UInt32 = OT_IMAGE_PROTOCOL_AUTO,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_scene_set_image",
      ot_scene_set_image_shim(self.context, self.handle, image.handle, fit, protocol),
    ),
  )
}
