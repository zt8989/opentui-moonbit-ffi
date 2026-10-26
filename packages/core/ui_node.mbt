// TS 兼容层：Renderable 统一节点（对应 @opentui/core 的
// BoxRenderable / TextRenderable）。属性用 TS 风格字符串，setter 立即
// 通过底层绑定提交（样式走属性记录流，绘制走 paint 记录整体替换）。

///|
pub enum NodeKind {
  RootNode
  BoxNode
  TextNode
  SliderNode
  CustomNode
  EditorNode
  TextViewNode
}

///|
/// Result[Unit, NativeError] → 异常（TS 层 setter 的统一错误路径）。
fn rethrow(r : Result[Unit, NativeError]) -> Unit raise {
  match r {
    Ok(_) => ()
    Err(e) => raise Failure(e.to_string())
  }
}

///|
/// 场景节点。new_box / new_text 构造，Renderer::root() 是场景根。
pub struct Renderable {
  context : Context
  session : OtHandle
  handle : OtHandle
  kind : NodeKind
  // 公开节点号（创建时分配；FrameBuffer 查表用）
  num : UInt32
  children : Array[Renderable]
  // paint 缓存（paint 记录是整体替换，任何绘制属性变更都要全量重建）
  mut background : RgbaColor
  mut border_sides : UInt32
  mut border_style : UInt32
  mut border_color : RgbaColor
  mut should_fill : UInt32
  mut opacity : Float
  mut z_index : Int32
  translate_x : Double
  translate_y : Double
  // text 缓存（text options 同为整体替换）
  mut content : String
  mut fg : RgbaColor
  mut text_bg : RgbaColor
  mut text_attributes : UInt32
  mut wrap_mode : UInt32
  mut truncate : Bool
  mut text_align : UInt32
}

///|
/// 创建 Box 的便捷别名（对齐 new BoxRenderable(renderer, {...})）。
/// Box 节点选项（字符串取值与 @opentui/core 的 BoxRenderable 构造参数对齐）。
pub struct BoxOptions {
  width : Size
  height : Size
  background : String
  border : Bool
  border_style : String
  border_color : String
  should_fill : Bool
  flex_direction : String
  justify_content : String
  align_items : String
  padding : Int32
  margin : Int32
  gap : Int32
  flex_grow : Double
  flex_shrink : Double
  overflow : String
  position : String
  top : String
  left : String
  right : String
  bottom : String
  z_index : Int32
  opacity : Double
}

///|
/// 带默认值的构造（缺省即 @opentui/core 的默认行为）。
pub fn BoxOptions::make(
  width~ : String = "auto",
  height~ : String = "auto",
  background~ : String = "transparent",
  border~ : Bool = false,
  border_style~ : String = "single",
  border_color~ : String = "white",
  should_fill~ : Bool = true,
  flex_direction~ : String = "column",
  justify_content~ : String = "flex-start",
  align_items~ : String = "stretch",
  padding~ : Int32 = 0,
  margin~ : Int32 = 0,
  gap~ : Int32 = 0,
  flex_grow~ : Double = 0.0,
  flex_shrink~ : Double = 1.0,
  overflow~ : String = "visible",
  position~ : String = "relative",
  top~ : String = "",
  left~ : String = "",
  right~ : String = "",
  bottom~ : String = "",
  z_index~ : Int32 = 0,
  opacity~ : Double = 1.0,
) -> BoxOptions {
  {
    width: Size::parse_lossy(width),
    height: Size::parse_lossy(height),
    background,
    border,
    border_style,
    border_color,
    should_fill,
    flex_direction,
    justify_content,
    align_items,
    padding,
    margin,
    gap,
    flex_grow,
    flex_shrink,
    overflow,
    position,
    top,
    left,
    right,
    bottom,
    z_index,
    opacity,
  }
}

///|
/// Text 节点选项（对应 new TextRenderable(renderer, {...}) 的参数）。
pub struct TextInput {
  content : String
  fg : String
  bg : String
  attributes : UInt32
  wrap_mode : String
  truncate : Bool
  align : String
}

///|
pub fn TextInput::make(
  content~ : String = "",
  fg~ : String = "white",
  bg~ : String = "transparent",
  attributes~ : String = "",
  wrap_mode~ : String = "none",
  truncate~ : Bool = false,
  align~ : String = "left",
) -> TextInput {
  {
    content,
    fg,
    bg,
    attributes: parse_attributes(attributes),
    wrap_mode,
    truncate,
    align,
  }
}

///|
/// 文本属性常量（对应 TS 的 attributes 位）。
pub const ATTR_BOLD : UInt32 = 1

///|
pub const ATTR_UNDERLINE : UInt32 = 8

///|
pub const ATTR_INVERSE : UInt32 = 32

///|
fn new_renderable(
  context : Context,
  session : OtHandle,
  kind : NodeKind,
  num~ : UInt32,
  paint~ : ScenePaintOptions,
) -> Renderable raise {
  let handle = next_node(context, session, kind, num~)
  let renderable : Renderable = {
    context,
    session,
    handle,
    kind,
    num,
    children: [],
    background: (0, 0, 0, 0),
    border_sides: 0,
    border_style: 0,
    border_color: (255, 255, 255, 255),
    should_fill: 0,
    opacity: 1.0,
    z_index: 0,
    translate_x: 0.0,
    translate_y: 0.0,
    content: "",
    fg: (255, 255, 255, 255),
    text_bg: (0, 0, 0, 0),
    text_attributes: 0,
    wrap_mode: 0,
    truncate: false,
    text_align: 0,
  }
  let _ = apply_paint(context, renderable, paint)
  renderable
}

///|
/// 空白 paint 记录（不透明、无边框；构造期占位，随后由缓存整体提交）。
fn empty_paint() -> ScenePaintOptions {
  {
    struct_size: 80,
    abi_version: OT_CONTEXT_ABI_VERSION,
    z_index: 0,
    opacity: 1.0,
    translate_x: 0.0,
    translate_y: 0.0,
    border_sides: 0,
    should_fill: 0,
    background01: 0,
    background23: 0,
    border_color01: 0,
    border_color23: 0,
    border_style: 0,
    focusable: 0,
    focused_border_color01: 0,
    focused_border_color23: 0,
    reserved: 0,
  }
}

///|
/// 创建 Box 节点（对应 new BoxRenderable(renderer, {...})；
/// 参数与 BoxRenderable 的构造选项同名，全部可省略）。
pub fn new_box(
  renderer : Renderer,
  width~ : String = "auto",
  height~ : String = "auto",
  background~ : String = "transparent",
  border~ : Bool = false,
  border_style~ : String = "single",
  border_color~ : String = "white",
  should_fill~ : Bool = true,
  flex_direction~ : String = "column",
  justify_content~ : String = "flex-start",
  align_items~ : String = "stretch",
  padding~ : Int32 = 0,
  margin~ : Int32 = 0,
  gap~ : Int32 = 0,
  flex_grow~ : Double = 0.0,
  flex_shrink~ : Double = 1.0,
  overflow~ : String = "visible",
  position~ : String = "relative",
  top~ : String = "",
  left~ : String = "",
  right~ : String = "",
  bottom~ : String = "",
  z_index~ : Int32 = 0,
  opacity~ : Double = 1.0,
) -> Renderable raise {
  let options = BoxOptions::make(
    width~,
    height~,
    background~,
    border~,
    border_style~,
    border_color~,
    should_fill~,
    flex_direction~,
    justify_content~,
    align_items~,
    padding~,
    margin~,
    gap~,
    flex_grow~,
    flex_shrink~,
    overflow~,
    position~,
    top~,
    left~,
    right~,
    bottom~,
    z_index~,
    opacity~,
  )
  let node = new_renderable(
    renderer.context,
    renderer.session,
    BoxNode,
    num=renderer.take_node_number(),
    paint=empty_paint(),
  )
  // 初始绘制属性
  node.set_background_internal(options.background)
  node.set_border_internal(
    options.border,
    options.border_style,
    options.border_color,
  )
  node.set_should_fill_internal(options.should_fill)
  node.set_opacity_internal(options.opacity)
  node.set_z_index_internal(options.z_index)
  // 构造期提交：set_*_internal 只改缓存，paint 是整体替换记录
  let _ = apply_paint(renderer.context, node, node.build_paint())
  // 初始布局样式：一次 flush
  let builder = StyleBuilder::new()
  builder.set_width(node.handle, options.width)
  builder.set_height(node.handle, options.height)
  builder.set_flex_direction(node.handle, options.flex_direction)
  builder.set_justify_content(node.handle, options.justify_content)
  builder.set_align_items(node.handle, options.align_items)
  builder.set_position_type(node.handle, options.position)
  if options.padding > 0 {
    builder.set_padding(node.handle, "all", pt(options.padding))
  }
  if options.margin > 0 {
    builder.set_margin(node.handle, "all", pt(options.margin))
  }
  if options.gap > 0 {
    builder.set_gap(node.handle, "all", pt(options.gap))
  }
  builder.set_flex_grow(node.handle, options.flex_grow)
  builder.set_flex_shrink(node.handle, options.flex_shrink)
  builder.set_overflow(node.handle, options.overflow)
  if options.top != "" {
    builder.set_position(node.handle, "top", Size::parse_lossy(options.top))
  }
  if options.left != "" {
    builder.set_position(node.handle, "left", Size::parse_lossy(options.left))
  }
  if options.right != "" {
    builder.set_position(node.handle, "right", Size::parse_lossy(options.right))
  }
  if options.bottom != "" {
    builder.set_position(
      node.handle,
      "bottom",
      Size::parse_lossy(options.bottom),
    )
  }
  let _ = flush_styles_of(renderer.context, builder)
  node
}

///|
/// 创建 Text 节点（对应 new TextRenderable(renderer, {...})；
/// 参数与 TextRenderable 的构造选项同名，全部可省略）。
pub fn new_text(
  renderer : Renderer,
  content~ : String = "",
  fg~ : String = "white",
  bg~ : String = "transparent",
  attributes~ : String = "",
  wrap_mode~ : String = "none",
  truncate~ : Bool = false,
  align~ : String = "left",
  width~ : String = "auto",
  height~ : String = "auto",
  position~ : String = "relative",
  top~ : String = "",
  left~ : String = "",
  right~ : String = "",
  bottom~ : String = "",
  z_index~ : Int32 = 0,
  flex_grow~ : Double = 0.0,
) -> Renderable raise {
  let options = TextInput::make(
    content~,
    fg~,
    bg~,
    attributes~,
    wrap_mode~,
    truncate~,
    align~,
  )
  let node = new_renderable(
    renderer.context,
    renderer.session,
    TextNode,
    num=renderer.take_node_number(),
    paint=empty_paint(),
  )
  let size_builder = StyleBuilder::new()
  size_builder.set_width(node.handle, Size::parse_lossy(width))
  size_builder.set_height(node.handle, Size::parse_lossy(height))
  let _ = flush_styles_of(renderer.context, size_builder)
  node.content = options.content
  node.fg = parse_color_lossy(options.fg)
  node.text_bg = parse_color_lossy(options.bg)
  node.text_attributes = options.attributes
  node.wrap_mode = parse_wrap_mode(options.wrap_mode)
  node.truncate = options.truncate
  node.text_align = match options.align {
    "center" => OT_SCENE_ALIGN_CENTER
    "right" => OT_SCENE_ALIGN_RIGHT
    _ => OT_SCENE_ALIGN_LEFT
  }
  let _ = apply_text(node.context, node)
  // 布局样式（与 new_box 对齐）：一次 flush
  let builder = StyleBuilder::new()
  builder.set_position_type(node.handle, position)
  if flex_grow != 0.0 {
    builder.set_flex_grow(node.handle, flex_grow)
  }
  if top != "" {
    builder.set_position(node.handle, "top", Size::parse_lossy(top))
  }
  if left != "" {
    builder.set_position(node.handle, "left", Size::parse_lossy(left))
  }
  if right != "" {
    builder.set_position(node.handle, "right", Size::parse_lossy(right))
  }
  if bottom != "" {
    builder.set_position(node.handle, "bottom", Size::parse_lossy(bottom))
  }
  if z_index != 0 {
    node.set_z_index_internal(z_index)
  }
  let _ = flush_styles_of(node.context, builder)
  node
}

///|
/// 追加子节点（对应 renderable.add(child)），追加到末尾。
pub fn Renderable::add(self : Renderable, child : Renderable) -> Unit raise {
  self.children.push(child)
  rethrow(
    move_child(
      self.context,
      child,
      self,
      index=(self.children.length() - 1).reinterpret_as_uint(),
    ),
  )
}

///|
pub fn Renderable::children_count(self : Renderable) -> Int32 {
  self.children.length()
}

///|
/// 子节点列表（只读用途；结构变更用 add）。
pub fn Renderable::children(self : Renderable) -> Array[Renderable] {
  self.children
}

///|
/// "flex" / "none"
pub fn Renderable::set_display(self : Renderable, value : String) -> Unit raise {
  self.update_style(fn(b, h) { b.set_display(h, value) })
}

///|
/// 更新文本内容（对应 text.content = "..."）。
pub fn Renderable::set_content(
  self : Renderable,
  content : String,
) -> Unit raise {
  self.content = content
  rethrow(apply_text(self.context, self))
}

///|
pub fn Renderable::get_content(self : Renderable) -> String {
  self.content
}

///|
pub fn Renderable::set_fg(self : Renderable, color : String) -> Unit raise {
  self.fg = parse_color_lossy(color)
  rethrow(apply_text(self.context, self))
}

///|
pub fn Renderable::set_bg(self : Renderable, color : String) -> Unit raise {
  self.text_bg = parse_color_lossy(color)
  rethrow(apply_text(self.context, self))
}

///|
pub fn Renderable::set_attributes(
  self : Renderable,
  attributes : UInt32,
) -> Unit raise {
  self.text_attributes = attributes
  rethrow(apply_text(self.context, self))
}

///|
/// "none" / "char" / "word"
pub fn Renderable::set_wrap_mode(
  self : Renderable,
  mode : String,
) -> Unit raise {
  self.wrap_mode = parse_wrap_mode(mode)
  rethrow(apply_text(self.context, self))
}

///|
pub fn Renderable::set_truncate(self : Renderable, on : Bool) -> Unit raise {
  self.truncate = on
  rethrow(apply_text(self.context, self))
}

///|
/// "left" / "center" / "right"
pub fn Renderable::set_align(self : Renderable, align : String) -> Unit raise {
  self.text_align = match align {
    "center" => OT_SCENE_ALIGN_CENTER
    "right" => OT_SCENE_ALIGN_RIGHT
    _ => OT_SCENE_ALIGN_LEFT
  }
  rethrow(apply_text(self.context, self))
}

///|
pub fn Renderable::set_background(
  self : Renderable,
  color : String,
) -> Unit raise {
  self.set_background_internal(color)
  rethrow(apply_paint(self.context, self, self.build_paint()))
}

///|
fn Renderable::set_background_internal(
  self : Renderable,
  color : String,
) -> Unit {
  self.background = parse_color_lossy(color)
}

///|
/// 开/关四边边框；style 为 "single"（当前原生层支持的样式编号 0）。
pub fn Renderable::set_border(
  self : Renderable,
  on : Bool,
  style~ : String = "single",
  color~ : String = "white",
) -> Unit raise {
  self.set_border_internal(on, style, color)
  rethrow(apply_paint(self.context, self, self.build_paint()))
}

///|
fn Renderable::set_border_internal(
  self : Renderable,
  on : Bool,
  style : String,
  color : String,
) -> Unit {
  self.border_sides = if on { OT_BORDER_ALL_SIDES } else { 0 }
  self.border_style = parse_border_style(style)
  self.border_color = parse_color_lossy(color)
}

///|
pub fn Renderable::set_should_fill(self : Renderable, on : Bool) -> Unit raise {
  self.set_should_fill_internal(on)
  rethrow(apply_paint(self.context, self, self.build_paint()))
}

///|
fn Renderable::set_should_fill_internal(self : Renderable, on : Bool) -> Unit {
  self.should_fill = if on { 1 } else { 0 }
}

///|
pub fn Renderable::set_opacity(self : Renderable, value : Double) -> Unit raise {
  self.set_opacity_internal(value)
  rethrow(apply_paint(self.context, self, self.build_paint()))
}

///|
fn Renderable::set_opacity_internal(self : Renderable, value : Double) -> Unit {
  self.opacity = Float::from_double(value)
}

///|
pub fn Renderable::set_z_index(self : Renderable, value : Int32) -> Unit raise {
  self.set_z_index_internal(value)
  rethrow(apply_paint(self.context, self, self.build_paint()))
}

///|
fn Renderable::set_z_index_internal(self : Renderable, value : Int32) -> Unit {
  self.z_index = value
}

///|
/// 布局样式更新入口：回调里通过 @core 的 StyleBuilder 声明变更，
/// 返回后统一提交（等价 TS 的多个属性 setter 共享一次重排）。
pub fn Renderable::update_style(
  self : Renderable,
  apply : (StyleBuilder, OtHandle) -> Unit raise,
) -> Unit raise {
  let builder = StyleBuilder::new()
  apply(builder, self.handle)
  let applied = flush_styles(self.context, builder)
  match applied {
    Ok(_) => ()
    Err(e) => raise Failure(e.to_string())
  }
}

///|
/// 由缓存状态重建完整 paint 记录（paint 是整体替换语义）。
fn Renderable::build_paint(self : Renderable) -> ScenePaintOptions {
  let bg = pack_rgba(self.background)
  let bc = pack_rgba(self.border_color)
  {
    struct_size: 80,
    abi_version: OT_CONTEXT_ABI_VERSION,
    z_index: self.z_index,
    opacity: self.opacity,
    translate_x: self.translate_x,
    translate_y: self.translate_y,
    border_sides: self.border_sides,
    should_fill: self.should_fill,
    background01: bg.0,
    background23: bg.1,
    border_color01: bc.0,
    border_color23: bc.1,
    border_style: self.border_style,
    focusable: 0,
    focused_border_color01: 0,
    focused_border_color23: 0,
    reserved: 0,
  }
}

///|
fn Renderable::build_text_options(self : Renderable) -> SceneTextOptions {
  let fg = pack_rgba(self.fg)
  let bg = pack_rgba(self.text_bg)
  {
    struct_size: 80,
    abi_version: OT_CONTEXT_ABI_VERSION,
    foreground01: fg.0,
    foreground23: fg.1,
    background01: bg.0,
    background23: bg.1,
    attributes: self.text_attributes,
    wrap_mode: self.wrap_mode,
    truncate: if self.truncate {
      1
    } else {
      0
    },
    first_line_offset: 0,
    scroll_x: 0.0,
    scroll_y: 0.0,
    tab_indicator: 0,
    tab_color_set: 0,
    tab_color01: 0,
    tab_color23: 0,
    text_align: self.text_align,
  }
}

///|
/// 文本滚动偏移（显示单元格；对应 TS textNode.scrollTo）。
pub fn Renderable::set_scroll(
  self : Renderable,
  x : Double,
  y : Double,
) -> Unit raise {
  rethrow(set_text_scroll_direct(self.context, self.handle, x, y))
}

