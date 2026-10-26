// TS 兼容层扩展：编辑器（对应 @opentui/core 的 EditBuffer / EditorView /
// TextareaRenderable）。两层模型：EditBuffer 持数据（文本/光标/撤销），
// EditorView 持视口与选区；OT_SCENE_EDITOR 节点绑定视图后由原生绘制
// （含光标）。extmark 用 ot_edit_buffer_highlight 的 ADD_RANGE 简化实现。

///|
/// 编辑缓冲（数据层，对应 EditBuffer）。
pub struct EditBuffer {
  context : Context
  handle : OtHandle
}

///|
/// 创建编辑缓冲。
pub fn EditBuffer::create(renderer : Renderer) -> EditBuffer raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let options : EditBufferOptions = {
    struct_size: 16,
    abi_version: OT_CONTEXT_ABI_VERSION,
    width_method: OT_WIDTH_METHOD_WCWIDTH,
    reserved: 0,
  }
  let status = ot_edit_buffer_create(renderer.context, options, out)
  rethrow_result(check("ot_edit_buffer_create", status))
  { context: renderer.context, handle: out.to_handle(), }
}

///|
/// 覆写全部文本。
pub fn EditBuffer::set_text(self : EditBuffer, text~ : String) -> Unit raise {
  let bytes = @utf8.encode(text)
  rethrow_result(
    check(
      "ot_edit_buffer_set_text",
      ot_edit_buffer_set_text(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
        0,
      ),
    ),
  )
}

///|
/// 光标处插入文本。
pub fn EditBuffer::insert_text(self : EditBuffer, text~ : String) -> Unit raise {
  let bytes = @utf8.encode(text)
  rethrow_result(
    check(
      "ot_edit_buffer_insert_text",
      ot_edit_buffer_insert_text(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 删除矩形范围（行/列坐标）。
pub fn EditBuffer::delete_range(
  self : EditBuffer,
  start_row~ : UInt32,
  start_col~ : UInt32,
  end_row~ : UInt32,
  end_col~ : UInt32,
) -> Unit raise {
  rethrow_result(
    check(
      "ot_edit_buffer_delete_range",
      ot_edit_buffer_delete_range(
        self.context,
        self.handle,
        start_row,
        start_col,
        end_row,
        end_col,
      ),
    ),
  )
}

///|
/// 设置光标（行/列）。
pub fn EditBuffer::set_cursor(self : EditBuffer, row~ : UInt32, col~ : UInt32) -> Unit raise {
  rethrow_result(
    check(
      "ot_edit_buffer_set_cursor",
      ot_edit_buffer_set_cursor(self.context, self.handle, row, col),
    ),
  )
}

///|
/// 读取全部文本。
pub fn EditBuffer::get_text(self : EditBuffer) -> String raise {
  rethrow_result(self.get_text_result())
}

fn EditBuffer::get_text_result(self : EditBuffer) -> Result[String, NativeError] {
  let buf : FixedArray[Byte] = FixedArray::make(16384, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  let status = ot_edit_buffer_get_text(self.context, self.handle, buf, 16384, out)
  match check("ot_edit_buffer_get_text", status) {
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
/// 缓冲信息：行数 / 光标行列 / 光标 offset。
pub struct EditBufferInfoView {
  line_count : Int
  cursor_row : Int
  cursor_col : Int
  cursor_offset : Int
}

///|
pub fn EditBufferInfoView::line_count(self : EditBufferInfoView) -> Int {
  self.line_count
}

///|
pub fn EditBufferInfoView::cursor_row(self : EditBufferInfoView) -> Int {
  self.cursor_row
}

///|
pub fn EditBufferInfoView::cursor_col(self : EditBufferInfoView) -> Int {
  self.cursor_col
}

///|
pub fn EditBufferInfoView::cursor_offset(self : EditBufferInfoView) -> Int {
  self.cursor_offset
}

///|
/// 读取缓冲信息。
pub fn EditBuffer::get_info(self : EditBuffer) -> EditBufferInfoView raise {
  let out : EditBufferInfo = {
    struct_size: 48,
    abi_version: OT_CONTEXT_ABI_VERSION,
    content_epoch: 0,
    byte_count: 0,
    line_count: 0,
    cursor_row: 0,
    cursor_col: 0,
    cursor_offset: 0,
    can_undo: 0,
    can_redo: 0,
    tab_width: 0,
  }
  rethrow_result(check("ot_edit_buffer_get_info", ot_edit_buffer_get_info(self.context, self.handle, out)))
  {
    line_count: out.line_count.reinterpret_as_int(),
    cursor_row: out.cursor_row.reinterpret_as_int(),
    cursor_col: out.cursor_col.reinterpret_as_int(),
    cursor_offset: out.cursor_offset.reinterpret_as_int(),
  }
}

///|
/// 缓冲命令（OT_EDIT_BACKSPACE / NEW_LINE / MOVE_LEFT 等）。
pub fn EditBuffer::command(self : EditBuffer, command~ : UInt32, argument~ : UInt32 = 0) -> Unit raise {
  rethrow_result(
    check(
      "ot_edit_buffer_command",
      ot_edit_buffer_command(self.context, self.handle, command, argument),
    ),
  )
}

///|
/// 设置 tab 宽度。
pub fn EditBuffer::set_tab_width(self : EditBuffer, width~ : UInt32) -> Unit raise {
  rethrow_result(
    check("ot_edit_buffer_set_tab_width", ot_edit_buffer_set_tab_width(self.context, self.handle, width)),
  )
}

///|
/// 位置查询结果（logical 行列 + display-width offset）。
pub struct BufferPosition {
  logical_row : Int
  logical_col : Int
  offset : Int
}

///|
pub fn BufferPosition::logical_row(self : BufferPosition) -> Int {
  self.logical_row
}

///|
pub fn BufferPosition::logical_col(self : BufferPosition) -> Int {
  self.logical_col
}

///|
pub fn BufferPosition::offset(self : BufferPosition) -> Int {
  self.offset
}

///|
/// offset → 行/列（query=OFFSET）。
pub fn EditBuffer::position_of_offset(self : EditBuffer, offset~ : Int) -> BufferPosition raise {
  self.query_position(OT_EDIT_POSITION_OFFSET, offset.reinterpret_as_uint(), 0)
}

///|
/// 行/列 → offset（query=COORDS）。
pub fn EditBuffer::offset_at(self : EditBuffer, row~ : Int, col~ : Int) -> BufferPosition raise {
  self.query_position(OT_EDIT_POSITION_COORDS, row.reinterpret_as_uint(), col.reinterpret_as_uint())
}

///|
/// 光标当前位置。
pub fn EditBuffer::cursor_position(self : EditBuffer) -> BufferPosition raise {
  self.query_position(OT_EDIT_POSITION_CURSOR, 0, 0)
}

///|
fn EditBuffer::query_position(
  self : EditBuffer,
  query : UInt32,
  a : UInt32,
  b : UInt32,
) -> BufferPosition raise {
  // ot_edit_position（24 字节，含 valid 位）——不是 editor view 的
  // ot_editor_position（28 字节）
  let out : EditPosition = {
    struct_size: 24,
    abi_version: OT_CONTEXT_ABI_VERSION,
    valid: 0,
    row: 0,
    col: 0,
    offset: 0,
  }
  rethrow_result(
    check(
      "ot_edit_buffer_get_position",
      ot_edit_buffer_get_position(self.context, self.handle, query, a, b, out),
    ),
  )
  {
    logical_row: out.row.reinterpret_as_int(),
    logical_col: out.col.reinterpret_as_int(),
    offset: out.offset.reinterpret_as_int(),
  }
}

///|
/// 添加范围高亮（extmark 简化实现：style_id 区分样式，ref 作删除句柄）。
pub fn EditBuffer::highlight_range(
  self : EditBuffer,
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
      "ot_edit_buffer_highlight",
      ot_edit_buffer_highlight_add_range_shim(self.context, self.handle, highlight),
    ),
  )
}

///|
/// 按 ref 移除高亮（ref 走 argument 参数；highlight 记录不参与）。
pub fn EditBuffer::highlight_remove(self : EditBuffer, ref_~ : UInt32) -> Unit raise {
  let highlight : EditHighlight = {
    start: 0,
    end: 0,
    style_id: 0,
    priority: 0,
    ref_: 0,
  }
  let _ = highlight
  rethrow_result(
    check(
      "ot_edit_buffer_highlight",
      ot_edit_buffer_highlight_remove_ref_shim(self.context, self.handle, ref_),
    ),
  )
}

///|
/// 清除全部高亮。
pub fn EditBuffer::highlight_clear(self : EditBuffer) -> Unit raise {
  rethrow_result(
    check(
      "ot_edit_buffer_highlight",
      ot_edit_buffer_highlight_clear_shim(self.context, self.handle),
    ),
  )
}

///|
/// 编辑器视图（视口/选区层，对应 EditorView）。
pub struct EditorView {
  context : Context
  handle : OtHandle
  buffer : EditBuffer
}

///|
/// 创建视图（绑定 buffer 的 width×height 视口）。
pub fn EditorView::create(
  renderer : Renderer,
  buffer : EditBuffer,
  width~ : UInt32,
  height~ : UInt32,
) -> EditorView raise {
  let out : HandleOut = { context_id: 0, slot: 0, generation: 0, }
  let status = ot_editor_view_create(renderer.context, buffer.handle, width, height, out)
  rethrow_result(check("ot_editor_view_create", status))
  { context: renderer.context, handle: out.to_handle(), buffer, }
}

///|
pub fn EditorView::buffer(self : EditorView) -> EditBuffer {
  self.buffer
}

///|
/// 设置视口（size_only=true 不移动光标）。
pub fn EditorView::set_viewport(
  self : EditorView,
  x~ : UInt32,
  y~ : UInt32,
  width~ : UInt32,
  height~ : UInt32,
  size_only~ : Bool = false,
  move_cursor~ : Bool = true,
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
      "ot_editor_view_set_viewport",
      ot_editor_view_set_viewport(
        self.context,
        self.handle,
        viewport,
        if size_only { 1 } else { 0 },
        if move_cursor { 1 } else { 0 },
      ),
    ),
  )
}

///|
/// 视图命令（OT_EDITOR_MOVE_UP/DOWN/GOTO_LINE_END/DELETE_SELECTION/CURSOR_OFFSET）。
pub fn EditorView::command(self : EditorView, command~ : UInt32, argument~ : UInt32 = 0) -> Unit raise {
  rethrow_result(
    check(
      "ot_editor_view_command",
      ot_editor_view_command(self.context, self.handle, command, argument),
    ),
  )
}

///|
/// 用文本替换当前选区（无选区时在光标处插入）。返回变更步数。
pub fn EditorView::replace_selection(self : EditorView, text~ : String) -> Int raise {
  let bytes = @utf8.encode(text)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_editor_view_replace_selection",
      ot_editor_view_replace_selection(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 视图信息：可见行数 / 选区存在与区间。
pub struct EditorViewInfoView {
  visible_lines : Int
  selection_present : Bool
  selection_start : Int
  selection_end : Int
}

///|
pub fn EditorViewInfoView::visible_lines(self : EditorViewInfoView) -> Int {
  self.visible_lines
}

///|
pub fn EditorViewInfoView::selection_present(self : EditorViewInfoView) -> Bool {
  self.selection_present
}

///|
pub fn EditorViewInfoView::selection_start(self : EditorViewInfoView) -> Int {
  self.selection_start
}

///|
pub fn EditorViewInfoView::selection_end(self : EditorViewInfoView) -> Int {
  self.selection_end
}

///|
/// 读取视图信息（follow_cursor=true 跟随光标滚动）。
pub fn EditorView::get_info(self : EditorView, follow_cursor~ : Bool = false) -> EditorViewInfoView raise {
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
      "ot_editor_view_get_info",
      ot_editor_view_get_info(
        self.context,
        self.handle,
        if follow_cursor { 1 } else { 0 },
        out,
      ),
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
pub fn EditorView::get_selected_text(self : EditorView) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(8192, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_editor_view_get_selected_text",
      ot_editor_view_get_selected_text(self.context, self.handle, buf, 8192, out),
    ),
  )
  let n = out[0].reinterpret_as_int()
  if n <= 0 {
    ""
  } else {
    @utf8.decode_lossy(Bytes::from_array(buf[:n]).exact_view())
  }
}

///|
/// 创建编辑器节点（对应 new TextareaRenderable(...)）：OT_SCENE_EDITOR
/// 节点绑定视图，原生绘制文本与光标。show_cursor 控制光标可见。
pub fn new_editor(
  renderer : Renderer,
  view : EditorView,
  width~ : String = "auto",
  height~ : String = "auto",
  show_cursor~ : Bool = true,
  position~ : String = "relative",
  top~ : String = "",
  left~ : String = "",
  z_index~ : Int32 = 0,
) -> Renderable raise {
  let num = renderer.take_node_number()
  let node = new_renderable(
    renderer.context,
    renderer.session,
    EditorNode,
    num~,
    paint=empty_paint(),
  )
  rethrow_result(check("ot_scene_set_editor_view", ot_scene_set_editor_view(renderer.context, node.handle, view.handle)))
  let options : SceneEditorOptions = {
    struct_size: 40,
    abi_version: OT_CONTEXT_ABI_VERSION,
    show_cursor: if show_cursor { 1 } else { 0 },
    style: 0,
    blinking: 0,
    reserved: 0,
    color01: 0,
    color23: 0,
    mouse_pointer: 0,
    reserved2: 0,
  }
  rethrow_result(
    check("ot_scene_set_editor_options", ot_scene_set_editor_options(renderer.context, node.handle, options)),
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
  node
}

///|
/// 设置编辑器选区（字符 offset 区间；update_cursor 同步光标到选区端点）。
pub fn EditorView::select(
  self : EditorView,
  start~ : Int,
  end~ : Int,
  update_cursor~ : Bool = true,
) -> Unit raise {
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
    update_cursor: if update_cursor { 1 } else { 0 },
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
      "ot_editor_view_select",
      ot_editor_view_select_shim(self.context, self.handle, selection, out),
    ),
  )
}

///|
/// 设置占位文本（缓冲为空且未选区时显示；纯文本简化版）。
pub fn EditorView::set_placeholder(self : EditorView, text~ : String) -> Unit raise {
  let bytes = @utf8.encode(text)
  rethrow_result(
    check(
      "ot_editor_view_set_placeholder",
      ot_editor_view_set_placeholder_text(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
      ),
    ),
  )
}

///|
/// 设置光标垂直滚动边距（视口顶部/底部保留的行数，0.5 步进）。
pub fn EditorView::set_scroll_margin(self : EditorView, margin~ : Double) -> Unit raise {
  rethrow_result(
    check(
      "ot_editor_view_set_scroll_margin",
      ot_editor_view_set_scroll_margin(self.context, self.handle, Float::from_double(margin)),
    ),
  )
}

///|
/// 设置制表符指示颜色。
pub fn EditorView::set_tab_color(self : EditorView, color~ : String) -> Unit raise {
  let c = parse_color_lossy(color)
  rethrow_result(
    check(
      "ot_editor_view_set_tab_color",
      ot_editor_view_set_tab_color(
        self.context,
        self.handle,
        { c01: pack_u16x2(c.0, c.1), c23: pack_u16x2(c.2, c.3) },
      ),
    ),
  )
}

///|
/// 读取换行后显示行。logical=false 读视口当前行（先跟随光标），
/// true 读整个文档。capacity=0 只报数量。
pub fn EditorView::get_lines(
  self : EditorView,
  logical~ : Bool = false,
  capacity~ : Int = 0,
) -> LinesResult raise {
  let cap = if capacity < 0 { 0 } else { capacity }
  let lines_buf : FixedArray[Byte] = FixedArray::make(if cap > 0 { cap * 16 } else { 1 }, 0)
  let out_pairs : FixedArray[UInt32] = FixedArray::make(2, 0)
  rethrow_result(
    check(
      "ot_editor_view_get_lines",
      ot_editor_view_get_lines_shim(
        self.context,
        self.handle,
        if logical { 1 } else { 0 },
        lines_buf,
        cap.reinterpret_as_uint(),
        out_pairs,
      ),
    ),
  )
  let returned = if cap > 0 { out_pairs[0].reinterpret_as_int() } else { 0 }
  parse_lines_result(lines_buf, returned, out_pairs[0].reinterpret_as_int(), out_pairs[1].reinterpret_as_int())
}

///|
/// 按 width×height 测量换行结果，返回 (line_count, width_cols_max)。
pub fn EditorView::measure(self : EditorView, width~ : Int, height~ : Int) -> (Int, Int) raise {
  let out_pairs : FixedArray[UInt32] = FixedArray::make(2, 0)
  rethrow_result(
    check(
      "ot_editor_view_measure",
      ot_editor_view_measure_shim(
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
/// 读取当前选区信息（不跟随光标）。
pub fn EditorView::get_selection(self : EditorView) -> EditorViewInfoView raise {
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
      "ot_editor_view_get_selection",
      ot_editor_view_get_selection(self.context, self.handle, out),
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
/// 撤销一步，返回交换出的文本片段（通常为空串）。
pub fn EditBuffer::undo(self : EditBuffer) -> String raise {
  self.history_step(0)
}

///|
/// 重做一步，返回交换出的文本片段。
pub fn EditBuffer::redo(self : EditBuffer) -> String raise {
  self.history_step(1)
}

///|
fn EditBuffer::history_step(self : EditBuffer, redo : UInt32) -> String raise {
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_edit_buffer_history",
      ot_edit_buffer_history(self.context, self.handle, redo, buf, 4096, out),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 预测量文本的显示宽度（不写入缓冲；tab 展开按缓冲的宽度方法与宽度）。
pub fn EditBuffer::measure_text(self : EditBuffer, text~ : String) -> Int raise {
  let bytes = @utf8.encode(text)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_edit_buffer_measure_text",
      ot_edit_buffer_measure_text(
        self.context,
        self.handle,
        bytes,
        bytes.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 无缓冲测量（指定宽度方法与 tab 宽度；tab_width=0 用默认 4）。
pub fn measure_text(
  renderer : Renderer,
  text~ : String,
  width_method~ : UInt32 = OT_WIDTH_METHOD_WCWIDTH,
  tab_width~ : UInt32 = 0,
) -> Int raise {
  let bytes = @utf8.encode(text)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_edit_measure_text",
      ot_edit_measure_text(
        renderer.context,
        bytes,
        bytes.length().reinterpret_as_uint(),
        width_method,
        tab_width,
        out,
      ),
    ),
  )
  out[0].reinterpret_as_int()
}

///|
/// 默认样式（未提供项不变；全空 + reset=true 重置）。
pub fn EditBuffer::set_defaults(
  self : EditBuffer,
  fg~ : String = "",
  bg~ : String = "",
  attributes~ : UInt32 = 0,
  reset~ : Bool = false,
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
  if reset {
    mask = 7
  }
  rethrow_result(
    check(
      "ot_edit_buffer_set_defaults",
      ot_edit_buffer_set_defaults_packed(
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
/// 按 display-column offset 区间取文本（by_coords=false）。
pub fn EditBuffer::get_range(self : EditBuffer, start~ : Int, end~ : Int) -> String raise {
  self.query_range(0, 0, start, 0, end)
}

///|
/// 按行列区间取文本。
pub fn EditBuffer::get_range_coords(
  self : EditBuffer,
  start_row~ : Int,
  start_col~ : Int,
  end_row~ : Int,
  end_col~ : Int,
) -> String raise {
  self.query_range(1, start_row, start_col, end_row, end_col)
}

///|
fn EditBuffer::query_range(
  self : EditBuffer,
  by_coords : UInt32,
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
) -> String raise {
  let span = if end_col > start_col && end_col - start_col < 16384 {
    end_col - start_col
  } else {
    16384
  }
  let buf : FixedArray[Byte] = FixedArray::make(span, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_edit_buffer_get_range",
      ot_edit_buffer_get_range(
        self.context,
        self.handle,
        by_coords,
        start_row.reinterpret_as_uint(),
        start_col.reinterpret_as_uint(),
        end_row.reinterpret_as_uint(),
        end_col.reinterpret_as_uint(),
        buf,
        buf.length().reinterpret_as_uint(),
        out,
      ),
    ),
  )
  decode_bytes(buf, out[0].reinterpret_as_int())
}

///|
/// 一条行内高亮：起止 display-column + 样式 id + ref。
pub struct HighlightView {
  start : Int
  end : Int
  style_id : UInt32
  priority : UInt32
  ref_ : UInt32
}

///|
pub fn HighlightView::start(self : HighlightView) -> Int {
  self.start
}

///|
pub fn HighlightView::end(self : HighlightView) -> Int {
  self.end
}

///|
pub fn HighlightView::style_id(self : HighlightView) -> UInt32 {
  self.style_id
}

///|
pub fn HighlightView::ref_(self : HighlightView) -> UInt32 {
  self.ref_
}

///|
/// 读取一行（display column 空间）上的高亮。capacity 默认 64。
pub fn EditBuffer::get_highlights(self : EditBuffer, line~ : Int, capacity~ : Int = 64) -> Array[HighlightView] raise {
  let cap = if capacity < 0 { 0 } else { capacity }
  let buf : FixedArray[Byte] = FixedArray::make(if cap > 0 { cap * 20 } else { 1 }, 0)
  let out : FixedArray[UInt32] = FixedArray::make(1, 0)
  rethrow_result(
    check(
      "ot_edit_buffer_get_highlights",
      ot_edit_buffer_get_highlights(
        self.context,
        self.handle,
        line.reinterpret_as_uint(),
        buf,
        cap.reinterpret_as_uint(),
        out,
      ),
    ),
  )
  let result : Array[HighlightView] = []
  let count = out[0].reinterpret_as_int()
  let mut i = 0
  while i < count {
    let base = i * 20
    let u32_at = fn(off : Int) -> UInt32 {
      buf[off].to_uint() |
      (buf[off + 1].to_uint() << 8) |
      (buf[off + 2].to_uint() << 16) |
      (buf[off + 3].to_uint() << 24)
    }
    result.push(
      {
        start: u32_at(base).reinterpret_as_int(),
        end: u32_at(base + 4).reinterpret_as_int(),
        style_id: u32_at(base + 8),
        priority: u32_at(base + 12),
        ref_: u32_at(base + 16),
      },
    )
    i += 1
  }
  result
}
