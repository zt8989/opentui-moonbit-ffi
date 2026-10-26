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
    struct_size: 36,
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
    struct_size: 64,
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
