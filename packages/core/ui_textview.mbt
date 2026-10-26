// TS 兼容层扩展：共享文本缓冲（对应 @opentui/core 的 TextBuffer /
// TextBufferView / SyntaxStyle / CodeRenderable）。TextBuffer 持数据与
// 富文本/高亮，TextBufferView 持视口与选区；OT_SCENE_TEXT_VIEW 节点绑定
// 视图后由原生绘制（无光标，与 EDITOR 节点的区别）。语法高亮：SyntaxStyle
// 是 name → 样式 id 表，宿主侧分词后用 ADD_RANGE 提交高亮。

///|
/// 语法样式表（name → fg/bg/attributes）。
pub struct SyntaxStyle {
  context : Context
  handle : OtHandle
}

///|
/// 创建空样式表。
pub fn SyntaxStyle::create(renderer : Renderer) -> SyntaxStyle raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(check("ot_syntax_style_create", ot_syntax_style_create(renderer.context, out)))
  { context: renderer.context, handle: out.to_handle(), }
}

///|
/// 销毁样式表（解除缓冲上的绑定引用）。
pub fn SyntaxStyle::destroy(self : SyntaxStyle) -> Unit raise {
  rethrow_result(check("ot_syntax_style_destroy", ot_syntax_style_destroy(self.context, self.handle)))
}

///|
/// 注册命名样式，返回样式 id（重名覆盖）。fg/bg 空串表示不设置该通道。
pub fn SyntaxStyle::register(
  self : SyntaxStyle,
  name~ : String,
  fg~ : String = "",
  bg~ : String = "",
  attributes~ : UInt32 = 0,
) -> UInt32 raise {
  let bytes = @utf8.encode(name)
  let fg_color : RgbaColor = if fg == "" { (0, 0, 0, 0) } else { parse_color_lossy(fg) }
  let bg_color : RgbaColor = if bg == "" { (0, 0, 0, 0) } else { parse_color_lossy(bg) }
  let (fg01, fg23) = pack_rgba(fg_color)
  let (bg01, bg23) = pack_rgba(bg_color)
  let mut flags : UInt32 = 0
  if fg != "" {
    flags = flags.lor(OT_EDITOR_STYLE_FOREGROUND)
  }
  if bg != "" {
    flags = flags.lor(OT_EDITOR_STYLE_BACKGROUND)
  }
  if attributes != 0 {
    flags = flags.lor(OT_EDITOR_STYLE_ATTRIBUTES)
  }
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_syntax_style_register",
      ot_syntax_style_register_packed(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
        flags,
        attributes,
        fg01,
        fg23,
        bg01,
        bg23,
        out,
      ),
    ),
  )
  out[0]
}

///|
/// 按名解析样式 id（未知名字返回 0）。
pub fn SyntaxStyle::resolve(self : SyntaxStyle, name~ : String) -> UInt32 raise {
  let bytes = @utf8.encode(name)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_syntax_style_resolve",
      ot_syntax_style_resolve(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  out[0]
}

///|
/// 已注册样式数量。
pub fn SyntaxStyle::get_count(self : SyntaxStyle) -> Int raise {
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(check("ot_syntax_style_get_count", ot_syntax_style_get_count(self.context, self.handle, out)))
  out[0].reinterpret_as_int()
}

///|
/// 共享文本缓冲（数据层：富文本 + 高亮 + 语法样式绑定）。
pub struct TextBuffer {
  context : Context
  handle : OtHandle
}

///|
/// 创建文本缓冲。
pub fn TextBuffer::create(renderer : Renderer) -> TextBuffer raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let options : EditBufferOptions = {
    struct_size: 16,
    abi_version: OT_CONTEXT_ABI_VERSION,
    width_method: OT_WIDTH_METHOD_WCWIDTH,
    reserved: 0,
  }
  rethrow_result(check("ot_text_buffer_create", ot_text_buffer_create(renderer.context, options, out)))
  { context: renderer.context, handle: out.to_handle(), }
}

///|
/// 销毁缓冲（级联销毁其视图，解绑场景节点）。
pub fn TextBuffer::destroy(self : TextBuffer) -> Unit raise {
  rethrow_result(check("ot_text_buffer_destroy", ot_text_buffer_destroy(self.context, self.handle)))
}

///|
/// 覆写全部文本（清除富文本与链接）。
pub fn TextBuffer::set_text(self : TextBuffer, text~ : String) -> Unit raise {
  let bytes = @utf8.encode(text)
  rethrow_result(
    check(
      "ot_text_buffer_set_text",
      ot_text_buffer_set_text(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 末尾追加文本。
pub fn TextBuffer::append(self : TextBuffer, text~ : String) -> Unit raise {
  let bytes = @utf8.encode(text)
  rethrow_result(
    check(
      "ot_text_buffer_append",
      ot_text_buffer_append(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 清空文本。reset=false 保留富文本高亮（丢链接）。
pub fn TextBuffer::clear(self : TextBuffer, reset~ : Bool = true) -> Unit raise {
  rethrow_result(
    check(
      "ot_text_buffer_clear",
      ot_text_buffer_clear(self.context, self.handle, if reset { 1 } else { 0 }),
    ),
  )
}

///|
/// 提交富文本（与场景节点的 set_styled_chunks 同一 chunk 模型；
/// fg 为 "inherit" 时只置前景标志用白色占位——缓冲层无继承色，建议显式给色）。
pub fn TextBuffer::set_styled_text(self : TextBuffer, chunks : Array[Chunk]) -> Unit raise {
  let mut total_bytes = 0
  let mut url_bytes = 0
  let encoded : Array[
    (Bytes, RgbaColor, RgbaColor, UInt32, UInt32, UInt32, UInt32, UInt32),
  ] = []
  for chunk in chunks {
    let bytes = @utf8.encode(chunk.text)
    let len = bytes.length().reinterpret_as_uint()
    let fg : RgbaColor = if chunk.fg == "inherit" || chunk.fg == "" {
      (255, 255, 255, 255)
    } else {
      parse_color_lossy(chunk.fg)
    }
    let bg : RgbaColor = if chunk.bg == "inherit" || chunk.bg == "transparent" || chunk.bg == "" {
      (0, 0, 0, 0)
    } else {
      parse_color_lossy(chunk.bg)
    }
    let mut flags = OT_SCENE_TEXT_FOREGROUND.lor(
      if bg.3 > 0 {
        OT_SCENE_TEXT_BACKGROUND
      } else {
        0
      },
    )
    let mut link_offset : UInt32 = 0
    let mut link_len : UInt32 = 0
    if chunk.url != "" {
      flags = flags.lor(OT_SCENE_TEXT_LINK)
      link_offset = url_bytes.reinterpret_as_uint()
      link_len = @utf8.encode(chunk.url).length().reinterpret_as_uint()
      url_bytes += link_len.reinterpret_as_int()
    }
    encoded.push((bytes, fg, bg, flags, chunk.attributes, len, link_offset, link_len))
    total_bytes += len.reinterpret_as_int()
  }
  let content : FixedArray[Byte] = FixedArray::make(if total_bytes > 0 { total_bytes } else { 1 }, 0)
  let chunk_buf : FixedArray[Byte] = FixedArray::make(encoded.length() * 48, 0)
  let url_buf : FixedArray[Byte] = FixedArray::make(if url_bytes > 0 { url_bytes } else { 1 }, 0)
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
    encode_styled_chunk(chunk_buf, i * 48, len, flags, fg, bg, attrs, link_off, link_len)
    offset += n
    url_offset += link_len.reinterpret_as_int()
  }
  rethrow_result(
    check(
      "ot_text_buffer_set_styled_text",
      ot_text_buffer_set_styled_text(
        self.context,
        self.handle,
        content,
        total_bytes.reinterpret_as_uint(),
        chunk_buf,
        encoded.length().reinterpret_as_uint(),
        url_buf,
        url_bytes.reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 绑定语法样式表。
pub fn TextBuffer::set_syntax_style(self : TextBuffer, style : SyntaxStyle) -> Unit raise {
  rethrow_result(
    check(
      "ot_text_buffer_set_syntax_style",
      ot_text_buffer_set_syntax_style(self.context, self.handle, style.handle),
    ),
  )
}

///|
/// 缓冲信息视图。
pub struct TextBufferInfoView {
  line_count : Int
  byte_count : Int
  text_length : Int
  highlight_count : Int
  tab_width : Int
}

///|
pub fn TextBufferInfoView::line_count(self : TextBufferInfoView) -> Int {
  self.line_count
}

///|
pub fn TextBufferInfoView::byte_count(self : TextBufferInfoView) -> Int {
  self.byte_count
}

///|
pub fn TextBufferInfoView::text_length(self : TextBufferInfoView) -> Int {
  self.text_length
}

///|
pub fn TextBufferInfoView::highlight_count(self : TextBufferInfoView) -> Int {
  self.highlight_count
}

///|
pub fn TextBufferInfoView::tab_width(self : TextBufferInfoView) -> Int {
  self.tab_width
}

///|
/// 读取缓冲信息。
pub fn TextBuffer::get_info(self : TextBuffer) -> TextBufferInfoView raise {
  let out : TextBufferInfo = {
    struct_size: 40,
    abi_version: OT_CONTEXT_ABI_VERSION,
    content_epoch: 0UL,
    byte_count: 0,
    text_length: 0,
    line_count: 0,
    highlight_count: 0,
    tab_width: 0,
    reserved: 0,
  }
  rethrow_result(check("ot_text_buffer_get_info", ot_text_buffer_get_info(self.context, self.handle, out)))
  {
    line_count: out.line_count.reinterpret_as_int(),
    byte_count: out.byte_count.reinterpret_as_int(),
    text_length: out.text_length.reinterpret_as_int(),
    highlight_count: out.highlight_count.reinterpret_as_int(),
    tab_width: out.tab_width.reinterpret_as_int(),
  }
}

///|
fn decode_bytes(buf : FixedArray[Byte], n : Int) -> String {
  if n <= 0 {
    ""
  } else {
    @utf8.decode_lossy(Bytes::from_array(buf[:n]).exact_view())
  }
}

///|
/// 读取全部文本。
pub fn TextBuffer::get_text(self : TextBuffer) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(16384, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_text_buffer_get_text",
      ot_text_buffer_get_text(self.context, self.handle, buf, 16384, out),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 按 display-column offset 区间取文本（区间自动吸附字素边界）。
pub fn TextBuffer::get_range(self : TextBuffer, start~ : Int, end~ : Int) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(
    if end > start && end - start < 16384 {
      end - start
    } else {
      16384
    },
    0,
  )
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_text_buffer_get_range",
      ot_text_buffer_get_range(
        self.context,
        self.handle,
        start.reinterpret_as_uint(),
        end.reinterpret_as_uint(),
        buf,
        buf.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 默认样式（f32 不适用；mask 按提供项自动计算）。全空 = 重置。
pub fn TextBuffer::set_defaults(
  self : TextBuffer,
  fg~ : String = "",
  bg~ : String = "",
  attributes~ : UInt32 = 0,
) -> Unit raise {
  let fg_color : RgbaColor = if fg == "" { (0, 0, 0, 0) } else { parse_color_lossy(fg) }
  let bg_color : RgbaColor = if bg == "" { (0, 0, 0, 0) } else { parse_color_lossy(bg) }
  let (fg01, fg23) = pack_rgba(fg_color)
  let (bg01, bg23) = pack_rgba(bg_color)
  let mut flags : UInt32 = 0
  let mut mask : UInt32 = 0
  if fg != "" {
    flags = flags.lor(OT_EDITOR_STYLE_FOREGROUND)
    mask = mask.lor(OT_EDITOR_STYLE_FOREGROUND)
  }
  if bg != "" {
    flags = flags.lor(OT_EDITOR_STYLE_BACKGROUND)
    mask = mask.lor(OT_EDITOR_STYLE_BACKGROUND)
  }
  if attributes != 0 {
    flags = flags.lor(OT_EDITOR_STYLE_ATTRIBUTES)
    mask = mask.lor(OT_EDITOR_STYLE_ATTRIBUTES)
  }
  rethrow_result(
    check(
      "ot_text_buffer_set_defaults",
      ot_text_buffer_set_defaults_packed(
        self.context,
        self.handle,
        mask,
        flags,
        attributes,
        fg01,
        fg23,
        bg01,
        bg23,
      ),
    ),
  )
}

///|
/// 设置 tab 宽度。
pub fn TextBuffer::set_tab_width(self : TextBuffer, width~ : UInt32) -> Unit raise {
  rethrow_result(
    check(
      "ot_text_buffer_set_tab_width",
      ot_text_buffer_set_tab_width(self.context, self.handle, width),
    ),
  )
}

///|
/// 添加范围高亮（富文本以 ref=0、priority=1 存储为高亮）。
pub fn TextBuffer::highlight_range(
  self : TextBuffer,
  start~ : Int,
  end~ : Int,
  style_id~ : UInt32,
  ref_~ : UInt32,
) -> Unit raise {
  let highlight : EditHighlight = {
    start: start.reinterpret_as_uint(),
    end: end.reinterpret_as_uint(),
    style_id,
    priority: 0,
    ref_,
  }
  rethrow_result(
    check(
      "ot_text_buffer_highlight",
      ot_text_buffer_highlight_add_range_shim(self.context, self.handle, highlight),
    ),
  )
}

///|
/// 按 ref 移除高亮。
pub fn TextBuffer::highlight_remove(self : TextBuffer, ref_~ : UInt32) -> Unit raise {
  rethrow_result(
    check(
      "ot_text_buffer_highlight",
      ot_text_buffer_highlight_remove_ref_shim(self.context, self.handle, ref_),
    ),
  )
}

///|
/// 清除全部高亮（含富文本段）。
pub fn TextBuffer::highlight_clear(self : TextBuffer) -> Unit raise {
  rethrow_result(
    check(
      "ot_text_buffer_highlight",
      ot_text_buffer_highlight_clear_shim(self.context, self.handle),
    ),
  )
}

///|
/// 创建视图（视口初始 0×0，需 set_viewport）。
pub fn TextBuffer::view(self : TextBuffer) -> TextBufferView raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  rethrow_result(
    check(
      "ot_text_buffer_view_create",
      ot_text_buffer_view_create(self.context, self.handle, out),
    ),
  )
  { context: self.context, handle: out.to_handle(), buffer: self }
}

///|
/// 文本缓冲视图（视口/选区层，对应 TextBufferView）。
pub struct TextBufferView {
  context : Context
  handle : OtHandle
  buffer : TextBuffer
}

///|
pub fn TextBufferView::buffer(self : TextBufferView) -> TextBuffer {
  self.buffer
}

///|
/// 设置视口（size_only=true 不改变滚动位置）。
pub fn TextBufferView::set_viewport(
  self : TextBufferView,
  x~ : UInt32,
  y~ : UInt32,
  width~ : UInt32,
  height~ : UInt32,
  size_only~ : Bool = false,
) -> Unit raise {
  let viewport : EditorViewport = {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    x,
    y,
    width,
    height,
  }
  rethrow_result(
    check(
      "ot_text_buffer_view_set_viewport",
      ot_text_buffer_view_set_viewport(
        self.context,
        self.handle,
        viewport,
        if size_only { 1 } else { 0 },
      ),
    ),
  )
}

///|
/// 视图命令（OT_EDITOR_MOVE_UP/DOWN/GOTO_LINE_END 等）。
pub fn TextBufferView::command(self : TextBufferView, command~ : UInt32, argument~ : UInt32 = 0) -> Unit raise {
  rethrow_result(
    check(
      "ot_text_buffer_view_command",
      ot_text_buffer_view_command(self.context, self.handle, command, argument),
    ),
  )
}

///|
/// 设置制表符指示颜色。
pub fn TextBufferView::set_tab_color(self : TextBufferView, color~ : String) -> Unit raise {
  let c = parse_color_lossy(color)
  rethrow_result(
    check(
      "ot_text_buffer_view_set_tab_color",
      ot_text_buffer_view_set_tab_color(
        self.context,
        self.handle,
        { c01: pack_u16x2(c.0, c.1), c23: pack_u16x2(c.2, c.3) },
      ),
    ),
  )
}

///|
/// 设置选区（display-column offset 区间）。
pub fn TextBufferView::select(self : TextBufferView, start~ : Int, end~ : Int) -> Unit raise {
  let selection : EditorSelection = {
    struct_size: 72,
    abi_version: OT_CONTEXT_ABI_VERSION,
    operation: OT_EDITOR_SELECT_SET,
    behavior: OT_SCENE_TEXT_SELECTION_CELL,
    start: start.reinterpret_as_uint(),
    end: end.reinterpret_as_uint(),
    anchor_x: 0,
    anchor_y: 0,
    focus_x: 0,
    focus_y: 0,
    update_cursor: 0,
    follow_cursor: 0,
    flags: 0,
    reserved: 0,
    foreground01: 0,
    foreground23: 0,
    background01: 0,
    background23: 0,
  }
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_text_buffer_view_select",
      ot_text_buffer_view_select(self.context, self.handle, selection, out),
    ),
  )
}

///|
/// 读取视图信息（虚拟行数 / 选区）。
pub fn TextBufferView::get_info(self : TextBufferView) -> EditorViewInfoView raise {
  let out : EditorViewInfo = {
    struct_size: 32,
    abi_version: OT_CONTEXT_ABI_VERSION,
    virtual_line_count: 0,
    total_virtual_line_count: 0,
    selection_present: 0,
    selection_start: 0,
    selection_end: 0,
    selection_occupancy: 0,
  }
  rethrow_result(
    check(
      "ot_text_buffer_view_get_info",
      ot_text_buffer_view_get_info(self.context, self.handle, out),
    ),
  )
  {
    visible_lines: out.virtual_line_count.reinterpret_as_int(),
    selection_present: out.selection_present != 0,
    selection_start: out.selection_start.reinterpret_as_int(),
    selection_end: out.selection_end.reinterpret_as_int(),
  }
}

///|
/// 读取选中文本。
pub fn TextBufferView::get_selected_text(self : TextBufferView) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(8192, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_text_buffer_view_get_selected_text",
      ot_text_buffer_view_get_selected_text(self.context, self.handle, buf, 8192, out),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 一条换行后显示行：起始列 / 宽度 / 源行 / 换行序号。
pub struct TextLine {
  start_cols : Int
  width_cols : Int
  source_line : Int
  wrap_index : Int
}

///|
pub fn TextLine::start_cols(self : TextLine) -> Int {
  self.start_cols
}

///|
pub fn TextLine::width_cols(self : TextLine) -> Int {
  self.width_cols
}

///|
pub fn TextLine::source_line(self : TextLine) -> Int {
  self.source_line
}

///|
pub fn TextLine::wrap_index(self : TextLine) -> Int {
  self.wrap_index
}

///|
/// 行列表查询结果。
pub struct LinesResult {
  lines : Array[TextLine]
  line_count : Int
  width_cols_max : Int
}

///|
pub fn LinesResult::lines(self : LinesResult) -> Array[TextLine] {
  self.lines
}

///|
pub fn LinesResult::line_count(self : LinesResult) -> Int {
  self.line_count
}

///|
pub fn LinesResult::width_cols_max(self : LinesResult) -> Int {
  self.width_cols_max
}

///|
fn parse_lines_result(
  lines_buf : FixedArray[Byte],
  returned : Int,
  line_count : Int,
  width_max : Int,
) -> LinesResult {
  let lines : Array[TextLine] = []
  let mut i = 0
  while i < returned {
    let base = i * 16
    let u32_at = fn(off : Int) -> UInt32 {
      lines_buf[off].to_uint() |
      (lines_buf[off + 1].to_uint() << 8) |
      (lines_buf[off + 2].to_uint() << 16) |
      (lines_buf[off + 3].to_uint() << 24)
    }
    lines.push(
      {
        start_cols: u32_at(base).reinterpret_as_int(),
        width_cols: u32_at(base + 4).reinterpret_as_int(),
        source_line: u32_at(base + 8).reinterpret_as_int(),
        wrap_index: u32_at(base + 12).reinterpret_as_int(),
      },
    )
    i += 1
  }
  { lines, line_count, width_cols_max: width_max }
}

///|
/// 读取换行后的显示行。logical=true 读整个文档（宽=最长未换行行），
/// 否则读视口行。capacity=0 只报数量。
pub fn TextBufferView::get_lines(
  self : TextBufferView,
  logical~ : Bool = false,
  first_line~ : Int = 0,
  capacity~ : Int = 0,
) -> LinesResult raise {
  let cap = if capacity < 0 { 0 } else { capacity }
  let lines_buf : FixedArray[Byte] = FixedArray::make(if cap > 0 { cap * 16 } else { 1 }, 0)
  let out_pairs : FixedArray[UInt32] = FixedArray::make(2, 0)
  rethrow_result(
    check(
      "ot_text_buffer_view_get_lines",
      ot_text_buffer_view_get_lines_shim(
        self.context,
        self.handle,
        if logical { 1 } else { 0 },
        first_line.reinterpret_as_uint(),
        lines_buf,
        cap.reinterpret_as_uint(),
        out_pairs,
      ),
    ),
  )
  // 零容量时返回数量在 out_pairs[0]
  let returned = if cap > 0 { out_pairs[0].reinterpret_as_int() } else { 0 }
  parse_lines_result(lines_buf, returned, out_pairs[0].reinterpret_as_int(), out_pairs[1].reinterpret_as_int())
}

///|
/// 按 width×height 测量换行结果，返回 (line_count, width_cols_max)。
pub fn TextBufferView::measure(self : TextBufferView, width~ : Int, height~ : Int) -> (Int, Int) raise {
  let out_pairs : FixedArray[UInt32] = FixedArray::make(2, 0)
  rethrow_result(
    check(
      "ot_text_buffer_view_measure",
      ot_text_buffer_view_measure_shim(
        self.context,
        self.handle,
        width.reinterpret_as_uint(),
        height.reinterpret_as_uint(),
        out_pairs,
      ),
    ),
  )
  (out_pairs[0].reinterpret_as_int(), out_pairs[1].reinterpret_as_int())
}

///|
/// 创建文本视图节点（对应 new TextBufferRenderable(...)）：OT_SCENE_TEXT_VIEW
/// 节点绑定视图，原生绘制（无光标）。paint_enabled=false 只关内置绘制，
/// 供 FrameBuffer 自绘路径（draw_text_view）使用。
pub fn new_text_view(
  renderer : Renderer,
  view : TextBufferView,
  width~ : String = "auto",
  height~ : String = "auto",
  position~ : String = "relative",
  top~ : String = "",
  left~ : String = "",
  z_index~ : Int32 = 0,
  paint_enabled~ : Bool = true,
) -> Renderable raise {
  let num = renderer.take_node_number()
  let node = new_renderable(
    renderer.context,
    renderer.session,
    TextViewNode,
    num~,
    paint=empty_paint(),
  )
  rethrow_result(
    check(
      "ot_scene_set_text_view",
      ot_scene_set_text_view(renderer.context, node.handle, view.handle),
    ),
  )
  if !paint_enabled {
    rethrow_result(
      check(
        "ot_scene_set_text_view_paint",
        ot_scene_set_text_view_paint(renderer.context, node.handle, 0),
      ),
    )
  }
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
