// 布局样式提交（ot_scene_flush 属性记录）与 TS 字符串枚举映射。
//
// STYLE 记录布局（共 40 字节，见 opentui.h）：
//   [ 0:16] ot_handle node（context_id u64 + slot u32 + generation u32）
//   [16:20] fields = OT_SCENE_PROPERTY_STYLE（必须为唯一字段位）
//   [20:24] size_bytes = 40
//   [24:28] group, kind, edge, unit（各 uint8）
//   [28:32] flags (uint32)
//   [32:36] value (float, 小端)
//   [36:40] reserved = 0
// 字节序为小端（arm64/x86_64）。

///|
/// 尺寸值：TS 里 width/height 的 number | "auto" | "50%"。
pub enum Size {
  Auto
  Pt(Double)
  Pct(Double)
}

///|
pub fn Size::parse(input : String) -> Size raise {
  let s = input.trim(chars=" ").to_owned()
  if s == "auto" || s == "" {
    return Auto
  }
  if s.has_suffix("%") {
    return Pct(parse_double(s[0:s.length() - 1].to_owned()))
  }
  Pt(parse_double(s))
}

///|
/// 解析失败的变体：Auto。
pub fn Size::parse_lossy(input : String) -> Size {
  Size::parse(input) catch {
    _ => Auto
  }
}

///|
/// Double 单元格便捷构造（支持负值偏移）。
pub fn ptd(value : Double) -> Size {
  Pt(value)
}

///|
/// 数字单元格便捷构造（对应 TS 的 number 尺寸）。
pub fn pt(value : Int32) -> Size {
  Pt(value.to_double())
}

///|
/// 百分比便捷构造。
pub fn pct(value : Double) -> Size {
  Pct(value)
}

///|
/// 手写小数解析（支持 [-]digits[.digits]；布局尺寸足够）。
fn parse_double(s : String) -> Double raise {
  let text = s.trim(chars=" ").to_owned()
  if text.length() == 0 {
    raise Failure("empty number")
  }
  let mut negative = false
  let mut index = 0
  let first = text[0]
  if first == 45 {
    negative = true
    index = 1
  } else if first == 43 {
    index = 1
  }
  let mut whole : Double = 0.0
  while index < text.length() && text[index] >= 48 && text[index] <= 57 {
    whole = whole * 10.0 + Double::from_int((text[index] - 48).to_int())
    index += 1
  }
  let mut fraction : Double = 0.0
  let mut scale = 0.1
  if index < text.length() && text[index] == 46 {
    index += 1
    while index < text.length() && text[index] >= 48 && text[index] <= 57 {
      fraction += Double::from_int((text[index] - 48).to_int()) * scale
      scale = scale * 0.1
      index += 1
    }
  }
  if index != text.length() {
    raise Failure("invalid number: \{s}")
  }
  if negative {
    -(whole + fraction)
  } else {
    whole + fraction
  }
}

///|
fn size_to_unit_value(size : Size) -> (UInt32, Float) {
  match size {
    Auto => (OT_UNIT_AUTO, 0.0)
    Pt(v) => (OT_UNIT_POINT, Float::from_double(v))
    Pct(v) => (OT_UNIT_PERCENT, Float::from_double(v))
  }
}

///|
fn parse_edge_lossy(s : String) -> UInt32 {
  parse_edge(s) catch {
    _ => OT_EDGE_ALL
  }
}

///|
fn parse_flex_direction_lossy(s : String) -> UInt32 {
  parse_flex_direction(s) catch {
    _ => OT_FLEX_DIRECTION_COLUMN
  }
}

///|
fn parse_justify_content_lossy(s : String) -> UInt32 {
  parse_justify_content(s) catch {
    _ => OT_JUSTIFY_FLEX_START
  }
}

///|
fn parse_align_lossy(s : String) -> UInt32 {
  parse_align(s) catch {
    _ => OT_ALIGN_STRETCH
  }
}

///|
fn parse_position_type_lossy(s : String) -> UInt32 {
  parse_position_type(s) catch {
    _ => OT_POSITION_RELATIVE
  }
}

///|
fn parse_flex_direction(s : String) -> UInt32 raise {
  match s {
    "column" => OT_FLEX_DIRECTION_COLUMN
    "column-reverse" => OT_FLEX_DIRECTION_COLUMN_REVERSE
    "row" => OT_FLEX_DIRECTION_ROW
    "row-reverse" => OT_FLEX_DIRECTION_ROW_REVERSE
    _ => raise Failure("unknown flexDirection: \{s}")
  }
}

///|
fn parse_justify_content(s : String) -> UInt32 raise {
  match s {
    "flex-start" => OT_JUSTIFY_FLEX_START
    "center" => OT_JUSTIFY_CENTER
    "flex-end" => OT_JUSTIFY_FLEX_END
    "space-between" => OT_JUSTIFY_SPACE_BETWEEN
    "space-around" => OT_JUSTIFY_SPACE_AROUND
    "space-evenly" => OT_JUSTIFY_SPACE_EVENLY
    _ => raise Failure("unknown justifyContent: \{s}")
  }
}

///|
fn parse_align(s : String) -> UInt32 raise {
  match s {
    "auto" => OT_ALIGN_AUTO
    "flex-start" => OT_ALIGN_FLEX_START
    "center" => OT_ALIGN_CENTER
    "flex-end" => OT_ALIGN_FLEX_END
    "stretch" => OT_ALIGN_STRETCH
    "baseline" => OT_ALIGN_BASELINE
    _ => raise Failure("unknown align: \{s}")
  }
}

///|
fn parse_position_type(s : String) -> UInt32 raise {
  match s {
    "relative" | "static" => OT_POSITION_RELATIVE
    "absolute" => OT_POSITION_ABSOLUTE
    _ => raise Failure("unknown positionType: \{s}")
  }
}

///|
fn parse_wrap_mode(s : String) -> UInt32 raise {
  match s {
    "none" => OT_SCENE_WRAP_NONE
    "char" => OT_SCENE_WRAP_CHAR
    "word" => OT_SCENE_WRAP_WORD
    _ => raise Failure("unknown wrapMode: \{s}")
  }
}

///|
/// 解析边名："left"/"right"/"top"/"bottom"/"all"。
pub fn parse_edge(s : String) -> UInt32 raise {
  match s {
    "left" => OT_EDGE_LEFT
    "top" => OT_EDGE_TOP
    "right" => OT_EDGE_RIGHT
    "bottom" => OT_EDGE_BOTTOM
    "all" => OT_EDGE_ALL
    _ => raise Failure("unknown edge: \{s}")
  }
}

///|
/// 文本属性字符串解析："bold underline" → 位标志。
pub fn parse_attributes(s : String) -> UInt32 {
  let mut bits : UInt32 = 0
  for token in s.split(" ").collect() {
    match token {
      "bold" => bits = bits.lor(OT_TEXT_ATTR_BOLD)
      "underline" => bits = bits.lor(OT_TEXT_ATTR_UNDERLINE)
      "inverse" => bits = bits.lor(OT_TEXT_ATTR_INVERSE)
      _ => ()
    }
  }
  bits
}

///|
/// 累积 style 属性记录，flush_styles() 一次性提交。
/// 方法名与 @opentui/core 的 Box 布局属性一一对应。
pub struct StyleBuilder {
  ops : Array[Byte]
  mut count : Int32
}

///|
pub fn StyleBuilder::new() -> StyleBuilder {
  { ops: [], count: 0, }
}

///|
pub fn StyleBuilder::record_count(self : StyleBuilder) -> Int32 {
  self.count
}

///|
fn StyleBuilder::push_u8(self : StyleBuilder, v : UInt32) -> Unit {
  self.ops.push((v & 0xff).reinterpret_as_int().to_byte())
}

///|
fn StyleBuilder::push_u32(self : StyleBuilder, v : UInt32) -> Unit {
  self.push_u8(v & 0xff)
  self.push_u8((v >> 8) & 0xff)
  self.push_u8((v >> 16) & 0xff)
  self.push_u8((v >> 24) & 0xff)
}

///|
fn StyleBuilder::push_f32(self : StyleBuilder, v : Float) -> Unit {
  self.push_u32(v.reinterpret_as_uint())
}

///|
fn StyleBuilder::push_u64(self : StyleBuilder, v : UInt64) -> Unit {
  for i in 0..<8 {
    self.push_u8(((v >> (i * 8)) & 0xff).to_uint())
  }
}

///|
/// 写入一条完整 STYLE 记录。
fn StyleBuilder::style_record(
  self : StyleBuilder,
  node : OtHandle,
  group : UInt32,
  kind : UInt32,
  edge : UInt32,
  unit : UInt32,
  flags : UInt32,
  value : Float,
) -> Unit {
  // [0:16] ot_handle
  self.push_u64(node.context_id)
  self.push_u32(node.slot)
  self.push_u32(node.generation)
  // [16:24] fields + size_bytes
  self.push_u32(OT_SCENE_PROPERTY_STYLE)
  self.push_u32(40)
  // [24:40] ot_scene_style_property payload
  self.push_u8(group)
  self.push_u8(kind)
  self.push_u8(edge)
  self.push_u8(unit)
  self.push_u32(flags)
  self.push_f32(value)
  self.push_u32(0)
  self.count += 1
}

///|
fn StyleBuilder::enum_record(
  self : StyleBuilder,
  node : OtHandle,
  kind : UInt32,
  value : UInt32,
) -> Unit {
  self.style_record(
    node,
    OT_STYLE_ENUM,
    kind,
    OT_EDGE_NONE,
    OT_UNIT_UNDEFINED,
    OT_STYLE_FLAGS_NONE,
    Float::from_int(value.reinterpret_as_int()),
  )
}

///|
fn StyleBuilder::float_record(
  self : StyleBuilder,
  node : OtHandle,
  kind : UInt32,
  value : Double,
) -> Unit {
  self.style_record(
    node,
    OT_STYLE_FLOAT,
    kind,
    OT_EDGE_NONE,
    OT_UNIT_UNDEFINED,
    OT_STYLE_FLAGS_NONE,
    Float::from_double(value),
  )
}

///|
fn StyleBuilder::edge_value_record(
  self : StyleBuilder,
  node : OtHandle,
  kind : UInt32,
  edge : UInt32,
  size : Size,
) -> Unit {
  let (unit, value) = size_to_unit_value(size)
  self.style_record(
    node,
    OT_STYLE_VALUE,
    kind,
    edge,
    unit,
    OT_STYLE_FLAGS_NONE,
    value,
  )
}

///|
fn StyleBuilder::dimension_record(
  self : StyleBuilder,
  node : OtHandle,
  kind : UInt32,
  size : Size,
) -> Unit {
  let (unit, value) = size_to_unit_value(size)
  self.style_record(
    node,
    OT_STYLE_DIMENSION,
    kind,
    OT_EDGE_NONE,
    unit,
    OT_STYLE_FLAGS_NONE,
    value,
  )
}

///|
pub fn StyleBuilder::set_width(
  self : StyleBuilder,
  node : OtHandle,
  size : Size,
) -> Unit {
  self.dimension_record(node, OT_STYLE_VALUE_WIDTH, size)
}

///|
pub fn StyleBuilder::set_height(
  self : StyleBuilder,
  node : OtHandle,
  size : Size,
) -> Unit {
  self.dimension_record(node, OT_STYLE_VALUE_HEIGHT, size)
}

///|
/// edge: "left"/"right"/"top"/"bottom"/"all"
pub fn StyleBuilder::set_padding(
  self : StyleBuilder,
  node : OtHandle,
  edge : String,
  size : Size,
) -> Unit {
  self.edge_value_record(
    node,
    OT_STYLE_VALUE_PADDING,
    parse_edge_lossy(edge),
    size,
  )
}

///|
/// edge: "left"/"right"/"top"/"bottom"/"all"
pub fn StyleBuilder::set_margin(
  self : StyleBuilder,
  node : OtHandle,
  edge : String,
  size : Size,
) -> Unit {
  self.edge_value_record(
    node,
    OT_STYLE_VALUE_MARGIN,
    parse_edge_lossy(edge),
    size,
  )
}

///|
/// edge: "left"/"right"/"top"/"bottom"
pub fn StyleBuilder::set_position(
  self : StyleBuilder,
  node : OtHandle,
  edge : String,
  size : Size,
) -> Unit {
  self.edge_value_record(
    node,
    OT_STYLE_VALUE_POSITION,
    parse_edge_lossy(edge),
    size,
  )
}

///|
/// edge: "left"/"right"/"top"/"bottom"/"all"
pub fn StyleBuilder::set_gap(
  self : StyleBuilder,
  node : OtHandle,
  edge : String,
  size : Size,
) -> Unit {
  self.edge_value_record(node, OT_STYLE_VALUE_GAP, parse_edge_lossy(edge), size)
}

///|
pub fn StyleBuilder::set_flex_basis(
  self : StyleBuilder,
  node : OtHandle,
  size : Size,
) -> Unit {
  self.edge_value_record(node, OT_STYLE_VALUE_FLEX_BASIS, OT_EDGE_NONE, size)
}

///|
pub fn StyleBuilder::set_flex_grow(
  self : StyleBuilder,
  node : OtHandle,
  value : Double,
) -> Unit {
  self.float_record(node, OT_STYLE_FLOAT_FLEX_GROW, value)
}

///|
pub fn StyleBuilder::set_flex_shrink(
  self : StyleBuilder,
  node : OtHandle,
  value : Double,
) -> Unit {
  self.float_record(node, OT_STYLE_FLOAT_FLEX_SHRINK, value)
}

///|
pub fn StyleBuilder::set_flex_direction(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(
    node,
    OT_STYLE_ENUM_FLEX_DIRECTION,
    parse_flex_direction_lossy(value),
  )
}

///|
pub fn StyleBuilder::set_justify_content(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(
    node,
    OT_STYLE_ENUM_JUSTIFY_CONTENT,
    parse_justify_content_lossy(value),
  )
}

///|
pub fn StyleBuilder::set_align_items(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(node, OT_STYLE_ENUM_ALIGN_ITEMS, parse_align_lossy(value))
}

///|
pub fn StyleBuilder::set_align_self(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(node, OT_STYLE_ENUM_ALIGN_SELF, parse_align_lossy(value))
}

///|
pub fn StyleBuilder::set_position_type(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(
    node,
    OT_STYLE_ENUM_POSITION_TYPE,
    parse_position_type_lossy(value),
  )
}

///|
/// "flex" / "none"（display:none 的节点不占布局也不绘制）
pub fn StyleBuilder::set_display(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(
    node,
    OT_STYLE_ENUM_DISPLAY,
    match value {
      "none" => OT_DISPLAY_NONE
      _ => OT_DISPLAY_FLEX
    },
  )
}

///|
pub fn StyleBuilder::set_overflow(
  self : StyleBuilder,
  node : OtHandle,
  value : String,
) -> Unit {
  self.enum_record(
    node,
    OT_STYLE_ENUM_OVERFLOW,
    match value {
      "visible" => OT_OVERFLOW_VISIBLE
      "hidden" => OT_OVERFLOW_HIDDEN
      _ => OT_OVERFLOW_VISIBLE
    },
  )
}

///|
/// 一次性提交全部累积记录，返回已应用记录数。
pub fn flush_styles(
  context : Context,
  builder : StyleBuilder,
) -> Result[UInt32, NativeError] {
  let bytes = Bytes::from_iter(builder.ops.iter())
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_scene_flush(
    context,
    bytes,
    bytes.length().reinterpret_as_uint(),
    out,
  )
  match check("ot_scene_flush", status) {
    Ok(_) => Ok(out[0])
    Err(e) => Err(e)
  }
}
