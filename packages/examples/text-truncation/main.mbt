// 移植自 packages/examples/src/text-truncation-demo.ts：
// 截断演示。t 键切换 truncate 开/关（配合固定宽度的文本节点）。

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
    content="TEXT TRUNCATION: off | t: toggle | q: quit",
    fg="#58a6ff",
    attributes="bold",
  )
  header.add(title)
  root.add(header)

  let body = @core.new_box(
    renderer,
    flex_direction="column",
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    padding=1,
    gap=1,
  )
  root.add(body)

  // 单行样例（宽度受限时超宽内容被截断）
  let lines = [
    "Single line: The quick brown fox jumps over the lazy dog repeatedly.", "Long single line: Pack my box with five dozen liquor jugs, then ship it overseas tomorrow morning.",
    "Wide glyphs: 你好，世界 —— 宽字符按显示宽度参与截断计算。",
  ]
  let samples : Array[@core.Renderable] = []
  for _i, line in lines {
    let row = @core.new_box(
      renderer,
      width="40",
      height="3",
      background="#16213e",
      border=true,
      border_color="#30363d",
    )
    let text = @core.new_text(renderer, content=line, fg="#c9d1d9")
    row.add(text)
    body.add(row)
    samples.push(text)
  }

  let mut truncated = false
  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    if stroke.name == "t" {
      truncated = !truncated
      let _ = title.set_content(
        "TEXT TRUNCATION: \{if truncated { "on" } else { "off" }} | t: toggle | q: quit",
      )
      for text in samples {
        let _ = text.set_truncate(truncated)
      }
      renderer.render()
    }
  })

  renderer.run()
}
