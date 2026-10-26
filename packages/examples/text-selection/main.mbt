// 移植自 packages/examples/src/text-selection-demo.ts：
// 跨渲染器的鼠标拖动选区（选区高亮由原生 ot_scene_set_text_selection 应用）。
// 鼠标左键拖动选择文本，跨 box/嵌套组；C 清除；q 退出。
// 状态面板显示选中行数/字符数、首尾行与选中渲染器计数。

///|
fn main raise {
  let renderer = @core.Renderer::create(width=96, height=34, background="#0d1117")
  renderer.enable_mouse()
  renderer.enable_selection()

  // 主容器
  let main_container = @core.new_box(
    renderer,
    width="88",
    height="22",
    background="#161b22",
    z_index=1,
    border=true,
    border_color="#50565d",
    position="absolute",
    left="1",
    top="1",
  )
  renderer.root().add(main_container)

  // 左组：文档段落
  let text_style : Array[@core.Chunk] = [
    @core.Chunk::make(text="This is a paragraph in the first box.", fg="#f0f6fc"),
    @core.Chunk::make(text="\nIt contains multiple lines of text", fg="#f0f6fc"),
    @core.Chunk::make(text="\nthat can be selected independently.", fg="#f0f6fc"),
    @core.Chunk::make(text="\n世界, 你好世界, 中文, 한글", fg="#f0f6fc"),
  ]
  let box1 = @core.new_box(
    renderer,
    width="45",
    height="7",
    background="#1e2936",
    z_index=20,
    border=true,
    border_color="#58a6ff",
    flex_direction="column",
    padding=1,
  )
  let text1 = @core.new_text(renderer, content="", fg="#f0f6fc")
  text1.set_styled_chunks(text_style)
  box1.add(text1)
  main_container.add(box1)

  // 嵌套盒：富文本 + 自定义选区色
  let nested_box = @core.new_box(
    renderer,
    width="31",
    height="4",
    background="#2d1b69",
    z_index=25,
    border=true,
    border_style="double",
    border_color="#a371f7",
    position="absolute",
    left="2",
    top="8",
  )
  let nested_text = @core.new_text(
    renderer,
    width="27",
    height="1",
    z_index=26,
  )
  nested_text.set_styled_chunks([
    @core.Chunk::make(text="Important:", fg="#e3b341", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text=" Nested content ", fg="#58a6ff"),
    @core.Chunk::make(text="with styles", fg="#3fb950", attributes=@core.ATTR_BOLD),
  ])
  nested_box.add(nested_text)
  main_container.add(nested_box)

  // 右组：代码示例
  let box2 = @core.new_box(
    renderer,
    width="35",
    height="12",
    background="#1c2128",
    z_index=20,
    border=true,
    border_style="rounded",
    border_color="#f85149",
    flex_direction="column",
    padding=1,
    position="absolute",
    left="48",
    top="2",
  )
  let code_text = @core.new_text(renderer, content="", fg="#e6edf3")
  code_text.set_styled_chunks([
    @core.Chunk::make(text="function handleSelection() {", fg="#d2a8ff"),
    @core.Chunk::make(text="\n  const selected = getSelectedText()", fg="#79c0ff"),
    @core.Chunk::make(text="\n  console.log(selected)", fg="#7ee787"),
    @core.Chunk::make(text="\n}", fg="#e6edf3"),
  ])
  box2.add(code_text)
  main_container.add(box2)

  // 浮动 README 盒（多行富文本，自定义选区色）
  let floating = @core.new_box(
    renderer,
    width="31",
    height="6",
    background="#1b2f23",
    z_index=30,
    border=true,
    border_color="#2ea043",
    position="absolute",
    left="64",
    top="11",
  )
  let multiline = @core.new_text(renderer, content="", fg="#e6edf3")
  multiline.set_styled_chunks([
    @core.Chunk::make(text="Selection Demo", fg="#79c0ff", attributes=@core.ATTR_BOLD),
    @core.Chunk::make(text="\n✓ Cross-renderable selection", fg="#3fb950"),
    @core.Chunk::make(text="\n✓ Nested groups and boxes", fg="#3fb950"),
    @core.Chunk::make(text="\n✓ Styled text support", fg="#3fb950"),
  ])
  floating.add(multiline)
  renderer.root().add(floating)

  let instructions = @core.new_text(
    renderer,
    content="Click and drag to select text across any elements. Press 'C' to clear selection.",
    fg="#f0f6fc",
    position="absolute",
    left="2",
    top="17",
    z_index=2,
  )
  main_container.add(instructions)

  // 状态面板
  let status_box = @core.new_box(
    renderer,
    width="88",
    height="9",
    background="#0d1117",
    z_index=1,
    border=true,
    border_color="#50565d",
    padding=1,
    position="absolute",
    left="1",
    top="24",
  )
  let status_text = @core.new_text(renderer, content="No selection - try selecting across different nested elements", fg="#f0f6fc")
  let selection_start = @core.new_text(renderer, content="", fg="#7dd3fc")
  let selection_middle = @core.new_text(renderer, content="", fg="#94a3b8")
  let debug_text = @core.new_text(renderer, content="", fg="#e6edf3")
  status_box.add(status_text)
  status_box.add(selection_start)
  status_box.add(selection_middle)
  status_box.add(debug_text)
  renderer.root().add(status_box)

  // 注册可选中节点（文本节点；nested/multiline 带自定义选区色）
  renderer.add_selectable(text1)
  renderer.add_selectable(nested_text, bg="#4a5568", fg="#ffffff")
  renderer.add_selectable(code_text, bg="#4a5568")
  renderer.add_selectable(multiline, bg="#4a5568", fg="#ffffff")

  // 选区回调（鼠标释放时触发）
  renderer.on_selection(fn(text, count) raise {
    if text == "" {
      let _ = status_text.set_content("Empty selection")
      let _ = selection_start.set_content("")
      let _ = selection_middle.set_content("")
      let _ = debug_text.set_content("Selected renderables: 0")
      renderer.render()
      return
    }
    let lines : Array[String] = []
    for part in text.split("\n") {
      lines.push(part.to_string())
    }
    let total = text.length()
    if lines.length() > 1 {
      let _ = status_text.set_content("Selected \{lines.length()} lines (\{total} chars):")
      let first = lines[lines.length() - 1]
      let _ = selection_start.set_content(lines[0])
      let _ = selection_middle.set_content("...")
      let _ = debug_text.set_content(first)
    } else if total > 60 {
      let _ = status_text.set_content("Selected \{total} chars:")
      let _ = selection_start.set_content(text.substring(start=0, end=30))
      let _ = selection_middle.set_content("...")
      let _ = debug_text.set_content(text.substring(start=total - 30, end=total))
    } else {
      let _ = status_text.set_content("Selected \{total} chars:")
      let _ = selection_start.set_content("\"\{text}\"")
      let _ = selection_middle.set_content("")
      let _ = debug_text.set_content("Selected renderables: \{count}")
    }
    renderer.render()
  })

  renderer.on_key(fn(stroke) {
    match stroke.name {
      "c" | "C" => {
        renderer.clear_selection()
        let _ = status_text.set_content("Selection cleared")
        let _ = selection_start.set_content("")
        let _ = selection_middle.set_content("")
        let _ = debug_text.set_content("")
        renderer.render()
      }
      "q" => renderer.stop()
      "escape" => renderer.stop()
      _ => ()
    }
  })

  renderer.render()
  renderer.run()
}
