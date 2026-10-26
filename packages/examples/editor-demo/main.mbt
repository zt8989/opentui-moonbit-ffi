// 移植自 packages/examples/src/editor-demo.ts（简化实现）：
// 多行编辑器 = EditBuffer + EditorView + OT_SCENE_EDITOR 节点。
// 演示批次新增的编辑器扩展：占位符（空缓冲显示）、滚动边距、
// 制表符颜色、缓冲命令（退格/换行/行首行尾）、撤销/重做、
// 选区信息读取。Shift+方向键选区，ctrl+z/y 撤销重做，q 退出。

///|
#borrow(name)
extern "C" fn getenv_ffi(name : Bytes) -> Int64 = "getenv"

///|
#borrow(path, mode)
extern "C" fn fopen_ffi(path : Bytes, mode : Bytes) -> Int64 = "fopen"

///|
#borrow(buf)
extern "C" fn fwrite_ffi(
  buf : FixedArray[Byte],
  size : UInt64,
  count : UInt64,
  file : Int64,
) -> UInt64 = "fwrite"

///|
extern "C" fn fclose_ffi(file : Int64) -> Int32 = "fclose"

///|
///|
fn write_info(path : String, lines : Array[String]) -> Unit {
  let file = fopen_ffi(@utf8.encode(path), b"w")
  if file == 0L {
    return
  }
  for line in lines {
    let bytes = @utf8.encode(line + "\n")
    let fa : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
    for i in 0..<bytes.length() {
      fa[i] = bytes[i]
    }
    let _ = fwrite_ffi(fa, 1UL, bytes.length().to_uint64(), file)
  }
  let _ = fclose_ffi(file)
}

///|
fn getenv_flag(name : String) -> Bool {
  let v = getenv_ffi(@utf8.encode(name))
  v != 0
}

///|
fn main raise {
  let headless = getenv_flag("OT_HEADLESS")
  let renderer = @core.Renderer::create(background="#10141a")
  let root = renderer.root()
  let frame_w = renderer.get_width().reinterpret_as_int()
  let frame_h = renderer.get_height().reinterpret_as_int()
  let edit_h = frame_h - 6

  // 编辑缓冲 + 视图（滚动边距 2：光标贴近上下边 2 行时提前滚动）
  let buffer = @core.EditBuffer::create(renderer)
  let view = @core.EditorView::create(
    renderer,
    buffer,
    width=(frame_w - 6).to_uint(),
    height=edit_h.to_uint(),
  )
  view.set_scroll_margin(margin=2.0)
  view.set_tab_color(color="#3d4753")
  view.set_placeholder(text="Type anything here (buffer is empty)")

  let editor = @core.new_editor(
    renderer,
    view,
    width="auto",
    height="\{edit_h}",
    position="absolute",
    left="2",
    top="1",
    show_cursor=true,
  )

  let frame = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#10141a",
    border=true,
    border_color="#30363d",
    padding=1,
  )
  frame.add(editor)

  let status = @core.new_text(renderer, content="", fg="#8b949e", position="absolute", left="1", top="\{frame_h - 3}")
  root.add(frame)
  root.add(status)

  buffer.set_text(
    text=
    #|Welcome to the Editor Demo!
    #|
    #|Arrow keys move, type to insert.
    #|Shift+arrows select, Backspace deletes.
    #|Ctrl+Z undo, Ctrl+Y redo, Ctrl+K clear (shows placeholder).
    #|Home/End jump to line start/end.
    #|
    #|Try the scroll margin: move down past the viewport edge.
  )

  let refresh = fn() raise {
    let info = buffer.get_info()
    ignore(info)
    let cur = buffer.cursor_position()
    let sel = view.get_selection()
    let sel_text = if sel.selection_present() {
      "sel [\{sel.selection_start()}..\{sel.selection_end()})"
    } else {
      "no selection"
    }
    let _ = status.set_content(
      " line \{cur.logical_row() + 1},col \{cur.logical_col()} · \{info.line_count()} lines · \{sel_text} · z/y undo/redo · k clear · q quit ",
    )
  }
  refresh()

  if headless {
    // 选区 + 测量 + 占位符状态写入 info 文件
    view.select(start=0, end=7, update_cursor=false)
    let sel = view.get_selection()
    let selected = view.get_selected_text()
    let measure = view.measure(width=(frame_w - 6), height=edit_h)
    // 占位符只在空缓冲显示；用临时空缓冲验证占位符行查询
    let empty_buffer = @core.EditBuffer::create(renderer)
    let empty_view = @core.EditorView::create(
      renderer,
      empty_buffer,
      width=20,
      height=3,
    )
    empty_view.set_placeholder(text="placeholder!")
    let placeholder_lines = empty_view.get_lines(logical=true, capacity=4).line_count()
    ignore(empty_view)
    ignore(empty_buffer)
    renderer.render()
    write_info(
      "editor-demo-info.txt",
      [
        "selection=\{sel.selection_present()} [\{sel.selection_start()}..\{sel.selection_end()}) text=\{selected}",
        "measure=(\{measure.0},\{measure.1})",
        "placeholder_lines=\{placeholder_lines}",
        "lines=\{buffer.get_info().line_count()}",
      ],
    )
    renderer.stop()
    return
  }

  renderer.on_key(fn(stroke) {
    let name = stroke.name
    if name == "q" || (stroke.ctrl && name == "c") {
      renderer.stop()
      return
    }
    // 可打印输入直接替换选区/插入（KeyStroke 无 text 字段，单字符 name 即输入）
    if name.length() == 1 && !stroke.ctrl && !stroke.meta {
      let _ = view.replace_selection(text=name)
      refresh()
      renderer.render()
      return
    }
    let handled : Bool = match name {
      "enter" => {
        buffer.command(command=@core.OT_EDIT_NEW_LINE)
        true
      }
      "backspace" => {
        if view.get_selection().selection_present() {
          view.command(command=@core.OT_EDITOR_DELETE_SELECTION)
        } else {
          buffer.command(command=@core.OT_EDIT_BACKSPACE)
        }
        true
      }
      "up" => {
        if stroke.shift {
          shift_select(view, buffer, 0, -1)
        } else {
          view.command(command=@core.OT_EDITOR_MOVE_UP)
        }
        true
      }
      "down" => {
        if stroke.shift {
          shift_select(view, buffer, 0, 1)
        } else {
          view.command(command=@core.OT_EDITOR_MOVE_DOWN)
        }
        true
      }
      "left" => {
        if stroke.shift {
          shift_select(view, buffer, -1, 0)
        } else {
          buffer.command(command=@core.OT_EDIT_MOVE_LEFT)
        }
        true
      }
      "right" => {
        if stroke.shift {
          shift_select(view, buffer, 1, 0)
        } else {
          buffer.command(command=@core.OT_EDIT_MOVE_RIGHT)
        }
        true
      }
      "home" => {
        buffer.command(command=@core.OT_EDIT_GOTO_LINE, argument=buffer.cursor_position().logical_row.reinterpret_as_uint())
        true
      }
      "end" => {
        let cur = buffer.cursor_position()
        let line_end = buffer.offset_at(row=cur.logical_row, col=100000)
        buffer.command(command=@core.OT_EDIT_CURSOR_OFFSET_CMD, argument=line_end.offset.reinterpret_as_uint())
        true
      }
      "z" => {
        if stroke.ctrl {
          let _ = buffer.undo()
          true
        } else {
          false
        }
      }
      "y" => {
        if stroke.ctrl {
          let _ = buffer.redo()
          true
        } else {
          false
        }
      }
      "k" => {
        if stroke.ctrl {
          buffer.set_text(text="")
          true
        } else {
          false
        }
      }
      _ => false
    }
    if handled {
      refresh()
      renderer.render()
    }
  })

  renderer.run()
}

///|
/// Shift+方向键的增量选区：以当前选区端点为锚，随移动方向扩展/收缩。
fn shift_select(
  view : @core.EditorView,
  buffer : @core.EditBuffer,
  dcol : Int,
  drow : Int,
) -> Unit raise {
  let sel = view.get_selection()
  let cur = buffer.cursor_position()
  // 锚点：已有选区取远离光标的端点，否则光标当前位置
  let anchor = if sel.selection_present() {
    let cur_off = buffer.offset_at(row=cur.logical_row, col=cur.logical_col).offset
    if (cur_off - sel.selection_start()).abs() > (cur_off - sel.selection_end()).abs() {
      sel.selection_start()
    } else {
      sel.selection_end()
    }
  } else {
    buffer.offset_at(row=cur.logical_row, col=cur.logical_col).offset
  }
  let row = (cur.logical_row + drow).clamp(min=0, max=100000)
  let col = (cur.logical_col + dcol).clamp(min=0, max=100000)
  let pos = buffer.offset_at(row=row, col=col)
  view.select(start=anchor, end=pos.offset, update_cursor=true)
}
