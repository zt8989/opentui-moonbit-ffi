// 移植自 packages/examples/src/clipboard-paste-demo.ts（简化实现）：
// 编辑器输入 + 终端粘贴事件（OT_INPUT_PASTE）+ OSC52 复制（ot_session_clipboard）。
// 与 TS 版的差异：host 剪贴板服务（createClipboard 的异步轮询生命周期）
// 未移植；读取依赖终端的粘贴路径（终端里 Cmd/Ctrl+V 发送的是带 braces
// 的粘贴文本，由原生解析成 paste 事件）。ctrl+u 把缓冲内容复制到终端剪贴板。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#071018")
  let frame_w = renderer.get_width().reinterpret_as_int()

  let buffer = @core.EditBuffer::create(renderer)
  buffer.set_text(text="Type here. Paste with the terminal paste key.\nCtrl+U copies the buffer via OSC52.")
  let view = @core.EditorView::create(
    renderer,
    buffer,
    width=(frame_w - 4).to_uint(),
    height=8,
  )

  let editor = @core.new_editor(
    renderer,
    view,
    height="10",
    position="absolute",
    left="2",
    top="1",
  )
  let root = @core.new_box(
    renderer,
    flex_grow=1.0,
    flex_direction="column",
    background="#071018",
    padding=1,
  )
  root.add(editor)

  let paste_status = @core.new_text(
    renderer,
    content="paste status: no paste received yet",
    fg="#8ba0b5",
    position="absolute",
    left="1",
    top="12",
  )
  let copy_status = @core.new_text(
    renderer,
    content="copy status: ready",
    fg="#8ba0b5",
    position="absolute",
    left="1",
    top="13",
  )
  let help = @core.new_text(
    renderer,
    content="type · paste (terminal paste key) · ctrl+u: copy buffer · ctrl+w: copy selection · q: quit",
    fg="#66d9ef",
    position="absolute",
    left="1",
    top="14",
  )
  root.add(paste_status)
  root.add(copy_status)
  root.add(help)
  renderer.root().add(root)

  renderer.on_paste(fn(text) raise {
    let bytes = @utf8.encode(text).length()
    // 粘贴进编辑器光标处
    let _ = view.replace_selection(text=text)
    let one_line = text.replace(old="\n", new="\\n").replace(old="\r", new="\\r")
    let preview = if one_line.length() > 32 {
      one_line.substring(start=0, end=32) + "…"
    } else {
      one_line
    }
    let _ = paste_status.set_content(
      "paste: \{bytes}B \"\{preview}\" → inserted at cursor",
    )
    renderer.render()
  })

  renderer.on_key(fn(stroke) raise {
    match stroke.name {
      "u" =>
        if stroke.ctrl {
          let text = buffer.get_text()
          let sent = renderer.copy_to_clipboard(text=text)
          let _ = copy_status.set_content(
            "copy: \{if sent { "sent via OSC52 (\{text.length()} chars)" } else { "unsupported by this terminal" } }",
          )
          renderer.render()
        } else {
          let _ = view.replace_selection(text="u")
        }
      "w" =>
        if stroke.ctrl {
          let info = view.get_info(follow_cursor=false)
          let text = view.get_selected_text()
          let sent = if info.selection_present() {
            renderer.copy_to_clipboard(text=text)
          } else {
            false
          }
          let _ = copy_status.set_content(
            "copy selection: \{if sent { "sent (\{text.length()} chars)" } else { if info.selection_present() { "unsupported" } else { "no selection" } } }",
          )
          renderer.render()
        } else {
          let _ = view.replace_selection(text="w")
        }
      "escape" | "q" => renderer.stop()
      _ => ()
    }
  })

  renderer.render()
  renderer.run()
}
