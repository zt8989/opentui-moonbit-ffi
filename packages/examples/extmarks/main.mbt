// 移植自 packages/examples/src/extmarks-demo.ts（简化实现）：
// 编辑器 + 虚拟标记（extmark）。TS 版的 ExtmarksController 是 JS 侧
// monkey-patch 模拟（845 行，官方注明未来原生化）；这里用
// ot_edit_buffer_highlight(ADD_RANGE) + MoonBit 侧按键逻辑实现同等行为：
// - 方向键移动光标，自动跳过 [MARKER] 范围
// - Backspace 在标记末尾删除整个标记
// - Ctrl+L 在光标处插入新标记
// 字符输入、回车正常编辑。ESC/q 退出。

///|
/// 一个标记：display-width offset 区间 + 高亮 ref + 文本
struct Marker {
  mut start : Int
  mut end : Int
  ref_id : UInt32
  text : String
}

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#10141a")
  let frame_w = renderer.get_width().reinterpret_as_int()

  let buffer = @core.EditBuffer::create(renderer)
  let view = @core.EditorView::create(
    renderer,
    buffer,
    width=(frame_w - 4).to_uint(),
    height=10,
  )

  let initial = "Welcome to the Extmarks Demo!\n\nMove the cursor through the [VIRTUAL] markers below:\n- Arrow keys navigate\n- The cursor skips over marker ranges\n- Backspace at the end deletes the whole marker\n\nExample text with [LINK:https://example.com] embedded.\nYou can also have [TAG:important] atomic tags.\n\nPress Ctrl+L to add a new [MARKER] at the cursor.\nPress ESC to quit."
  buffer.set_text(text=initial)

  let editor = @core.new_editor(
    renderer,
    view,
    width="auto",
    height="12",
    position="absolute",
    left="2",
    top="1",
  )
  let root = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#10141a",
    padding=1,
  )
  root.add(editor)

  let status = @core.new_text(
    renderer,
    content="",
    fg="#8b949e",
    position="absolute",
    left="1",
    top="14",
  )
  root.add(status)
  renderer.root().add(root)

  // 初始标记：[VIRTUAL] 两处 + [LINK:...] + [TAG:...]（用 offset_at 换算）
  let markers : Array[Marker] = []
  let mut next_ref : UInt32 = 1
  for target in ["[VIRTUAL]", "[LINK:https://example.com]", "[TAG:important]"] {
    // 逐个查找（文本里 [VIRTUAL] 出现两次，第二次从头次之后找）
    let full = buffer.get_text()
    let idx = find_nth(full, target, if target == "[VIRTUAL]" { 1 } else { 1 })
    match idx {
      Some(i) => {
        let start_pos = buffer.offset_at(row=0, col=0)
        ignore(start_pos)
        // offset_at 用行列查询；这里直接换算：初始文本逐行累计
        let off = offset_of_index(full, i)
        let end_off = off + display_width(target)
        let ref_id = next_ref
        next_ref = next_ref + 1
        buffer.highlight_range(start=off, end=end_off, style_id=1, ref_=ref_id)
        markers.push({ start: off, end: end_off, ref_id, text: target })
      }
      None => ()
    }
  }

  let update_status = fn() raise {
    let info = buffer.get_info()
    let _ = status.set_content(
      "cursor \{info.cursor_row()},\{info.cursor_col()} (offset \{info.cursor_offset()}) · arrows move (skip markers) · backspace deletes marker · ctrl+l insert · esc quit",
    )
    renderer.render()
  }

  // 光标 offset（视图当前光标）
  let cursor_off = fn() -> Int raise {
    buffer.cursor_position().offset()
  }

  // 光标移到指定 offset（edit buffer 的 CURSOR_OFFSET 命令编号 9）
  let move_cursor_to = fn(off : Int) raise {
    // 通过行列设置：offset → 行列
    let pos = buffer.position_of_offset(offset=off)
    buffer.set_cursor(row=pos.logical_row().reinterpret_as_uint(), col=pos.logical_col().reinterpret_as_uint())
  }

  renderer.on_key(fn(stroke) raise {
    match stroke.name {
      "left" | "right" => {
        let mut off = cursor_off()
        let delta = if stroke.name == "right" { 1 } else { -1 }
        off = off + delta
        // 标记跳过：右移进入标记内部 → 跳到末尾；左移 → 跳到开头
        for m in markers {
          if delta == 1 && off > m.start && off < m.end {
            off = m.end
          } else if delta == -1 && off > m.start && off <= m.end {
            off = m.start
          }
        }
        if off >= 0 {
          move_cursor_to(off)
        }
        update_status()
      }
      "up" | "down" => {
        // 上下移动不跳标记（保持行为简单）；marker 范围随内容移动由高亮 ref 维护
        view.command(
          command=if stroke.name == "up" { @core.OT_EDITOR_MOVE_UP } else { @core.OT_EDITOR_MOVE_DOWN },
        )
        update_status()
      }
      "backspace" => {
        let off = cursor_off()
        // 命中标记末尾：整删
        let mut marker_hit : Marker? = None
        for m in markers {
          if off == m.end {
            marker_hit = Some(m)
            break
          }
        }
        match marker_hit {
          Some(m) => {
            // offset → 行列，删除 [start, end)
            let sp = buffer.position_of_offset(offset=m.start)
            let ep = buffer.position_of_offset(offset=m.end)
            buffer.delete_range(
              start_row=sp.logical_row().reinterpret_as_uint(),
              start_col=sp.logical_col().reinterpret_as_uint(),
              end_row=ep.logical_row().reinterpret_as_uint(),
              end_col=ep.logical_col().reinterpret_as_uint(),
            )
            buffer.highlight_remove(ref_=m.ref_id)
            // 后续标记区间前移
            let width = m.end - m.start
            for other in markers {
              if other.ref_id != m.ref_id && other.start >= m.end {
                other.start = other.start - width
                other.end = other.end - width
              }
            }
            let keep : Array[Marker] = []
            for m2 in markers {
              if m2.ref_id != m.ref_id {
                keep.push(m2)
              }
            }
            markers.clear()
            for m2 in keep {
              markers.push(m2)
            }
            move_cursor_to(m.start)
          }
          None => {
            // 普通退格：选中前一字符后替换为空
            let off2 = cursor_off()
            if off2 > 0 {
              view.select(start=off2 - 1, end=off2)
              let _ = view.replace_selection(text="")
            }
          }
        }
        update_status()
      }
      "enter" => {
        let _ = view.replace_selection(text="\n")
        update_status()
      }
      "l" =>
        if stroke.ctrl {
          // 插入新标记
          let label = "[MARKER]"
          let _ = view.replace_selection(text=label)
          let off = cursor_off()
          let m_end = off
          let m_start = off - display_width(label)
          let ref_id = next_ref
          next_ref = next_ref + 1
          buffer.highlight_range(start=m_start, end=m_end, style_id=1, ref_=ref_id)
          markers.push({ start: m_start, end: m_end, ref_id, text: label })
          update_status()
        } else {
          let _ = view.replace_selection(text="l")
          update_status()
        }
      "escape" => renderer.stop()
      "q" => renderer.stop()
      _ =>
        // 可打印字符直接插入
        if stroke.name.length() == 1 && !stroke.ctrl && !stroke.meta {
          let _ = view.replace_selection(text=stroke.name)
          // 插入后标记区间后移
          for m in markers {
            if m.start >= cursor_off() - stroke.name.length() {
              m.start = m.start + stroke.name.length()
              m.end = m.end + stroke.name.length()
            }
          }
          update_status()
        }
    }
  })

  update_status()
  renderer.run()
}

///|
/// 在文本中查找第 n 次出现的下标（1 起）。
fn find_nth(text : String, needle : String, n : Int) -> Int? {
  let mut count = 0
  let mut i = 0
  let nchars = text.length()
  let pat : Array[Int] = []
  for j in 0..<needle.length() {
    pat.push(needle[j].to_int())
  }
  while i + pat.length() <= nchars {
    let mut ok = true
    for j in 0..<pat.length() {
      if text[i + j].to_int() != pat[j] {
        ok = false
        break
      }
    }
    if ok {
      count += 1
      if count == n {
        return Some(i)
      }
    }
    i += 1
  }
  None
}

///|
/// 字符下标 → display-width offset（按前缀宽度累计；ASCII 记 1，
/// 宽字符由原生测宽，这里简化统一按 1 计——初始文本以 ASCII 为主）。
fn offset_of_index(text : String, index : Int) -> Int {
  // display-width offset 与字符下标在 ASCII 前缀下一致
  index
}

///|
/// 标记文本显示宽度（简化：按字符数）。
fn display_width(text : String) -> Int {
  text.length()
}
