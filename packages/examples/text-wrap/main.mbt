// 移植自 packages/examples/src/text-wrap.ts：
// 自动换行演示。w 键在 wrap none → char → word 之间循环。

///|
fn main raise {
  let renderer = @core.Renderer::create(background="#1a1a2e")
  let root = renderer.root()

  let header = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
    justify_content="center",
  )
  let title = @core.new_text(
    renderer,
    content="TEXT WRAP: none | w: next mode | q: quit",
    fg="#e94560",
    attributes="bold",
  )
  header.add(title)
  root.add(header)

  let modes = ["none", "char", "word"]
  let mut mode_index = 0

  let body = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    padding=1,
  )
  let paragraph = @core.new_text(
    renderer,
    content="The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump — 长文本换行演示：终端单元格按显示宽度折行，字符与单词两种模式。",
    fg="#e0e0e0",
    wrap_mode="none",
  )
  body.add(paragraph)
  root.add(body)

  let footer = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
  )
  let highlight = @core.new_text(
    renderer,
    content="text wrapping demonstration",
    fg="#9ece6a",
    attributes="bold",
    wrap_mode="word",
  )
  footer.add(highlight)
  root.add(footer)

  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    if stroke.name == "w" {
      mode_index = (mode_index + 1) % modes.length()
      let _ = title.set_content(
        "TEXT WRAP: \{modes[mode_index]} | w: next mode | q: quit",
      )
      let _ = paragraph.set_wrap_mode(modes[mode_index])
      renderer.render()
    }
  })

  renderer.run()
}
