// 移植自 packages/examples/src/scroll-example.ts：
// 长文本滚动（text options 的 scroll_y）。↑/↓ 或 j/k 滚动，q 退出。

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
  let status = @core.new_text(
    renderer,
    content="SCROLL | ↑/↓ or j/k: scroll · q quit",
    fg="#e94560",
    attributes="bold",
  )
  header.add(status)
  root.add(header)

  // 固定高度的内容框：文本超出部分通过 scroll_y 露出
  let viewport = @core.new_box(
    renderer,
    flex_grow=1.0,
    background="#0f3460",
    border=true,
    border_color="#533483",
    padding=1,
    overflow="hidden",
  )
  let lines : Array[String] = []
  for i in 1..<41 {
    lines.push("line \{i}: the scroll demo keeps forty lines of content here.")
  }
  let body = @core.new_text(renderer, content=lines.join("\n"), fg="#c0caf5")
  viewport.add(body)
  root.add(viewport)

  let footer = @core.new_box(
    renderer,
    height="3",
    background="#16213e",
    border=true,
    align_items="center",
  )
  let readout = @core.new_text(renderer, content=" scroll: 0.0", fg="#aebbf0")
  footer.add(readout)
  root.add(footer)

  let mut scroll_y = 0.0
  renderer.on_key(fn(stroke) raise {
    if stroke.name == "q" || (stroke.ctrl && stroke.name == "c") {
      renderer.stop()
      return
    }
    let delta : Double? = match stroke.name {
      "down" | "j" => Some(1.0)
      "up" | "k" => Some(-1.0)
      _ => None
    }
    match delta {
      Some(d) => {
        scroll_y = scroll_y + d
        if scroll_y < 0.0 {
          scroll_y = 0.0
        }
        // scroll_y 通过 update_style 的 text options 路径更新：
        // TextNode 的滚动在 core 里由 set_scroll 暴露
        let _ = body.set_scroll(scroll_y, 0.0)
        let _ = readout.set_content(" scroll: \{scroll_y}")
        renderer.render()
      }
      None => ()
    }
  })

  renderer.run()
}
